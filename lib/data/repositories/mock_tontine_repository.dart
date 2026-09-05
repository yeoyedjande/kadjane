import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/domain/services/period_calculator.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// TODO(api): remplacer par `RestTontineRepository`
/// (/organizations/{id}/tontines).
class MockTontineRepository implements TontineRepository {
  MockTontineRepository(
    this._db,
    this._audit, [
    this._rules = const TontineRulesService(),
    this._periods = const PeriodCalculator(),
  ]);

  final MockDatabase _db;
  final AuditRepository _audit;
  final TontineRulesService _rules;
  final PeriodCalculator _periods;

  @override
  Future<List<TontineSummary>> list({
    required String organizationId,
    TontineStatus? status,
    String? memberId,
  }) => _db.withLatency(() {
    return _db
        .tontinesOf(organizationId)
        .where((Tontine t) => status == null || t.status == status)
        .where(
          (Tontine t) =>
              memberId == null ||
              _db
                  .participantsOf(t.id)
                  .any((TontineParticipant p) => p.memberId == memberId),
        )
        .map(_buildSummary)
        .toList(growable: false);
  });

  @override
  Future<TontineSummary> summaryOf(String tontineId) =>
      _db.withLatency(() => _buildSummary(_db.tontineById(tontineId)));

  @override
  Future<Tontine> byId(String tontineId) =>
      _db.withLatency(() => _db.tontineById(tontineId));

  @override
  Future<Tontine> create({
    required String organizationId,
    required TontineDraft draft,
    required String actorMemberId,
  }) async {
    if (draft.memberIds.length < 2) {
      throw const ValidationException('min_two_participants');
    }
    final Tontine tontine = await _db.withLatency(() {
      // Les règles du tirage sont héritées des réglages de l'organisation :
      // même contrat que le serveur, sinon le mode démo mentirait.
      final OrganizationSettings settings = _db
          .organizationById(organizationId)
          .settings;
      final Tontine created = Tontine(
        id: _db.nextId('ton'),
        organizationId: organizationId,
        name: draft.name,
        description: draft.description,
        contributionAmount: draft.contributionAmount,
        currency: draft.currency,
        frequency: draft.frequency,
        allocationMode: draft.allocationMode,
        startDate: draft.startDate,
        dueDayOfPeriod: draft.dueDayOfPeriod,
        drawDay: draft.drawDayOfPeriod,
        customPeriodDays: draft.customPeriodDays,
        status: TontineStatus.active,
        createdAt: DateTime.now(),
        createdBy: actorMemberId,
        requireAllContributionsBeforeDraw:
            settings.requireFullPaymentBeforeDraw,
        allowDrawOverride: settings.allowDrawOverride,
      );
      _db.tontines.add(created);

      // Ordre manuel : on respecte l'ordre fourni par l'administrateur.
      final List<String> orderedIds =
          draft.allocationMode == AllocationMode.manualOrder &&
              draft.manualOrder.length == draft.memberIds.length
          ? draft.manualOrder
          : draft.memberIds;

      for (int i = 0; i < orderedIds.length; i++) {
        final String memberId = orderedIds[i];
        _db.participants.add(
          TontineParticipant(
            id: _db.nextId('prt'),
            tontineId: created.id,
            memberId: memberId,
            displayName: _db.memberById(memberId).fullName,
            joinedAt: DateTime.now(),
            orderPosition: draft.allocationMode == AllocationMode.manualOrder
                ? i + 1
                : null,
          ),
        );
      }

      final double expected = draft.contributionAmount * orderedIds.length;
      final List<PeriodBounds> bounds = _periods.generate(
        startDate: draft.startDate,
        frequency: draft.frequency,
        count: orderedIds.length,
        dueDayOfPeriod: draft.dueDayOfPeriod,
        customPeriodDays: draft.customPeriodDays,
      );
      for (int i = 0; i < bounds.length; i++) {
        _db.cycles.add(
          TontineCycle(
            id: _db.nextId('cyc'),
            tontineId: created.id,
            index: i + 1,
            periodStart: bounds[i].start,
            periodEnd: bounds[i].end,
            dueDate: bounds[i].dueDate,
            drawScheduledAt: _periods.drawOpeningFor(
              periodStart: bounds[i].start,
              periodEnd: bounds[i].end,
              drawDay: created.drawDayOfPeriod,
            ),
            expectedAmount: expected,
            status: i == 0 ? CycleStatus.collecting : CycleStatus.upcoming,
          ),
        );
      }
      return created;
    });

    await _audit.record(
      organizationId: organizationId,
      action: AuditAction.tontineCreated,
      description: 'La tontine « ${tontine.name} » a été créée.',
      actorMemberId: actorMemberId,
      tontineId: tontine.id,
      targetType: 'tontine',
      targetId: tontine.id,
    );
    return tontine;
  }

  @override
  Future<Tontine> update({
    required Tontine tontine,
    required String actorMemberId,
  }) async {
    final Tontine updated = await _db.withLatency(() {
      _db.replaceTontine(tontine);
      return tontine;
    });
    await _audit.record(
      organizationId: tontine.organizationId,
      action: AuditAction.tontineUpdated,
      description: 'La tontine « ${tontine.name} » a été mise à jour.',
      actorMemberId: actorMemberId,
      tontineId: tontine.id,
      targetType: 'tontine',
      targetId: tontine.id,
    );
    return updated;
  }

  @override
  Future<Tontine> changeStatus({
    required String tontineId,
    required TontineStatus status,
    required String actorMemberId,
  }) async {
    final Tontine updated = await _db.withLatency(() {
      final Tontine tontine = _db.tontineById(tontineId);
      final Tontine next = tontine.copyWith(
        status: status,
        closedAt: status.isFinished ? DateTime.now() : null,
      );
      _db.replaceTontine(next);
      return next;
    });
    await _audit.record(
      organizationId: updated.organizationId,
      action: AuditAction.tontineStatusChanged,
      description:
          'Le statut de « ${updated.name} » est passé à ${status.code}.',
      actorMemberId: actorMemberId,
      tontineId: updated.id,
      targetType: 'tontine',
      targetId: updated.id,
    );
    return updated;
  }

  @override
  Future<List<TontineParticipant>> participants(String tontineId) =>
      _db.withLatency(() {
        final List<TontineParticipant> list = _db.participantsOf(tontineId);
        final List<TontineParticipant> sorted = List<TontineParticipant>.of(
          list,
        );
        sorted.sort((TontineParticipant a, TontineParticipant b) {
          final int? pa = a.orderPosition;
          final int? pb = b.orderPosition;
          if (pa != null && pb != null) {
            return pa.compareTo(pb);
          }
          return a.displayName.compareTo(b.displayName);
        });
        return sorted;
      });

  @override
  Future<List<TontineCycle>> cycles(String tontineId) =>
      _db.withLatency(() => _db.cyclesOf(tontineId));

  @override
  Future<TontineCycle> cycleById(String cycleId) =>
      _db.withLatency(() => _db.cycleById(cycleId));

  @override
  Future<TontineCycle?> currentCycle(String tontineId) =>
      _db.withLatency(() => _currentCycleOf(tontineId));

  @override
  Future<void> setManualOrder({
    required String tontineId,
    required List<String> participantIdsInOrder,
    required String actorMemberId,
  }) async {
    await _db.withLatency(() {
      for (int i = 0; i < participantIdsInOrder.length; i++) {
        final TontineParticipant participant = _db.participantById(
          participantIdsInOrder[i],
        );
        _db.replaceParticipant(participant.copyWith(orderPosition: i + 1));
      }
    });
    final Tontine tontine = _db.tontineById(tontineId);
    await _audit.record(
      organizationId: tontine.organizationId,
      action: AuditAction.orderGenerated,
      description:
          'L\'ordre de passage de « ${tontine.name} » a été défini manuellement.',
      actorMemberId: actorMemberId,
      tontineId: tontineId,
      targetType: 'tontine',
      targetId: tontineId,
    );
  }

  // --- Interne -------------------------------------------------------------

  TontineCycle? _currentCycleOf(String tontineId) {
    final List<TontineCycle> cycles = _db.cyclesOf(tontineId);
    if (cycles.isEmpty) {
      return null;
    }
    final DateTime now = DateTime.now();
    for (final TontineCycle cycle in cycles) {
      if (!now.isBefore(cycle.periodStart) && !now.isAfter(cycle.periodEnd)) {
        return cycle;
      }
    }
    for (final TontineCycle cycle in cycles) {
      if (cycle.status != CycleStatus.closed) {
        return cycle;
      }
    }
    return cycles.last;
  }

  TontineSummary _buildSummary(Tontine tontine) {
    final List<TontineParticipant> participants = _db.participantsOf(
      tontine.id,
    );
    final List<TontineCycle> cycles = _db.cyclesOf(tontine.id);
    final TontineCycle? current = _currentCycleOf(tontine.id);
    final List<Contribution> currentContributions = current == null
        ? const <Contribution>[]
        : _db.contributionsOfCycle(current.id);

    final int completed = cycles
        .where((TontineCycle c) => c.status == CycleStatus.closed)
        .length;

    final List<Beneficiary> beneficiaries =
        _db.beneficiaries
            .where((Beneficiary b) => b.tontineId == tontine.id)
            .toList()
          ..sort(
            (Beneficiary a, Beneficiary b) =>
                b.designatedAt.compareTo(a.designatedAt),
          );

    final Beneficiary? currentBeneficiary = current == null
        ? null
        : _db.beneficiaryOfCycle(current.id);

    return TontineSummary(
      tontine: tontine,
      participantCount: participants.length,
      completedCycles: completed,
      totalCycles: cycles.length,
      collectedCurrentCycle: _rules.collectedAmount(currentContributions),
      expectedCurrentCycle: current?.expectedAmount ?? 0,
      currentCycle: current,
      currentBeneficiaryName: currentBeneficiary?.memberName,
      previousBeneficiaryName: beneficiaries
          .where((Beneficiary b) => b.cycleId != current?.id)
          .map((Beneficiary b) => b.memberName)
          .firstOrNull,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final Iterator<E> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
