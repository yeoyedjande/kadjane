import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/core/utils/period_label.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// TODO(api): remplacer par `RestContributionRepository`
/// (/tontines/{id}/contributions).
class MockContributionRepository implements ContributionRepository {
  MockContributionRepository(
    this._db,
    this._audit, [
    this._rules = const TontineRulesService(),
  ]);

  final MockDatabase _db;
  final AuditRepository _audit;
  final TontineRulesService _rules;

  @override
  Future<List<ContributionSlot>> slotsForCycle(String cycleId) =>
      _db.withLatency(() {
        final TontineCycle cycle = _db.cycleById(cycleId);
        final Tontine tontine = _db.tontineById(cycle.tontineId);
        final List<Contribution> contributions = _db.contributionsOfCycle(
          cycleId,
        );
        return _rules
            .contributors(_db.participantsOf(tontine.id))
            .map(
              (TontineParticipant p) => ContributionSlot(
                memberId: p.memberId,
                memberName: p.displayName,
                avatarUrl: p.avatarUrl,
                expectedAmount: tontine.contributionAmount,
                contribution: _activeContributionOf(contributions, p.memberId),
              ),
            )
            .toList(growable: false);
      });

  @override
  Future<List<Contribution>> forCycle(String cycleId) =>
      _db.withLatency(() => _sorted(_db.contributionsOfCycle(cycleId)));

  @override
  Future<List<Contribution>> forTontine(String tontineId) =>
      _db.withLatency(() => _sorted(_db.contributionsOfTontine(tontineId)));

  @override
  Future<List<Contribution>> forMember({
    required String organizationId,
    required String memberId,
  }) => _db.withLatency(
    () => _sorted(
      _db.contributions
          .where(
            (Contribution c) =>
                c.organizationId == organizationId && c.memberId == memberId,
          )
          .toList(),
    ),
  );

  @override
  Future<Contribution> record({
    required ContributionDraft draft,
    required String actorMemberId,
  }) async {
    if (draft.amount <= 0) {
      throw const ValidationException('amount_must_be_positive');
    }
    final Contribution contribution = await _db.withLatency(() {
      final TontineCycle cycle = _db.cycleById(draft.cycleId);
      final Tontine tontine = _db.tontineById(cycle.tontineId);
      final TontineParticipant? participant = _rules.participantOf(
        _db.participantsOf(tontine.id),
        draft.memberId,
      );
      if (participant == null) {
        throw const BusinessRuleException('member_not_participant');
      }
      final Contribution created = Contribution(
        id: _db.nextId('ctr'),
        organizationId: tontine.organizationId,
        tontineId: tontine.id,
        cycleId: cycle.id,
        memberId: draft.memberId,
        memberName: participant.displayName,
        amount: draft.amount,
        status: draft.status,
        method: draft.method,
        reference: draft.reference,
        comment: draft.comment,
        attachmentId: draft.attachmentId,
        paidAt: draft.paidAt ?? DateTime.now(),
        recordedBy: actorMemberId,
        recordedAt: DateTime.now(),
      );
      _db.contributions.add(created);
      _refreshCycleStatus(cycle);
      return created;
    });

    await _audit.record(
      organizationId: contribution.organizationId,
      action: AuditAction.contributionRecorded,
      description:
          '${contribution.memberName} — cotisation de '
          '${MoneyFormatter.format(contribution.amount, _db.tontineById(contribution.tontineId).currency)} '
          'enregistrée pour '
          '${PeriodLabel.monthYear(_db.cycleById(contribution.cycleId).periodStart)}.',
      actorMemberId: actorMemberId,
      tontineId: contribution.tontineId,
      targetType: 'contribution',
      targetId: contribution.id,
      amount: contribution.amount,
    );
    return contribution;
  }

  @override
  Future<Contribution> confirm({
    required String contributionId,
    required String actorMemberId,
  }) async {
    final Contribution updated = await _db.withLatency(() {
      final Contribution current = _byId(contributionId);
      if (current.status == ContributionStatus.cancelled) {
        throw const BusinessRuleException('cannot_confirm_cancelled');
      }
      final Contribution next = current.copyWith(
        status: ContributionStatus.confirmed,
        paidAt: current.paidAt ?? DateTime.now(),
      );
      _db.replaceContribution(next);
      _refreshCycleStatus(_db.cycleById(next.cycleId));
      return next;
    });
    await _audit.record(
      organizationId: updated.organizationId,
      action: AuditAction.contributionConfirmed,
      description: 'La cotisation de ${updated.memberName} a été confirmée.',
      actorMemberId: actorMemberId,
      tontineId: updated.tontineId,
      targetType: 'contribution',
      targetId: updated.id,
      amount: updated.amount,
    );
    return updated;
  }

  @override
  Future<Contribution> cancel({
    required String contributionId,
    required String reason,
    required String actorMemberId,
  }) async {
    final Contribution updated = await _db.withLatency(() {
      final Contribution current = _byId(contributionId);
      // Aucune suppression : la ligne reste dans l'historique, marquée annulée.
      final Contribution next = current.copyWith(
        status: ContributionStatus.cancelled,
        cancelledAt: DateTime.now(),
        cancelReason: reason,
      );
      _db.replaceContribution(next);
      _refreshCycleStatus(_db.cycleById(next.cycleId));
      return next;
    });
    await _audit.record(
      organizationId: updated.organizationId,
      action: AuditAction.contributionCancelled,
      description:
          'La cotisation de ${updated.memberName} a été annulée ($reason).',
      actorMemberId: actorMemberId,
      tontineId: updated.tontineId,
      targetType: 'contribution',
      targetId: updated.id,
      amount: updated.amount,
    );
    return updated;
  }

  // --- Interne -------------------------------------------------------------

  Contribution _byId(String id) => _db.contributions.firstWhere(
    (Contribution c) => c.id == id,
    orElse: () => throw NotFoundException('contribution:$id'),
  );

  /// Cotisation à afficher pour un membre : la confirmée si elle existe,
  /// sinon la plus récente non annulée.
  Contribution? _activeContributionOf(
    List<Contribution> contributions,
    String memberId,
  ) {
    final List<Contribution> forMember =
        contributions.where((Contribution c) => c.memberId == memberId).toList()
          ..sort(
            (Contribution a, Contribution b) =>
                b.recordedAt.compareTo(a.recordedAt),
          );
    for (final Contribution c in forMember) {
      if (c.status == ContributionStatus.confirmed) {
        return c;
      }
    }
    for (final Contribution c in forMember) {
      if (c.status == ContributionStatus.pending) {
        return c;
      }
    }
    return forMember.isEmpty ? null : forMember.first;
  }

  /// Passe le cycle en « prêt pour le tirage » dès que tout est collecté.
  void _refreshCycleStatus(TontineCycle cycle) {
    if (cycle.hasBeneficiary || cycle.status == CycleStatus.closed) {
      return;
    }
    final Tontine tontine = _db.tontineById(cycle.tontineId);
    final CycleFinancials financials = _rules.financialsFor(
      tontine: tontine,
      cycle: cycle,
      participants: _db.participantsOf(tontine.id),
      contributions: _db.contributionsOfCycle(cycle.id),
    );
    _db.replaceCycle(
      cycle.copyWith(
        status: financials.unpaidMembers == 0
            ? CycleStatus.readyForDraw
            : CycleStatus.collecting,
      ),
    );
  }

  List<Contribution> _sorted(List<Contribution> source) {
    final List<Contribution> list = List<Contribution>.of(source);
    list.sort(
      (Contribution a, Contribution b) => b.recordedAt.compareTo(a.recordedAt),
    );
    return List<Contribution>.unmodifiable(list);
  }
}
