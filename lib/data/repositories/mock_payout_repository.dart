import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/payout_repository.dart';

/// TODO(api): remplacer par `RestPayoutRepository` (/tontines/{id}/payouts).
class MockPayoutRepository implements PayoutRepository {
  MockPayoutRepository(this._db, this._audit);

  final MockDatabase _db;
  final AuditRepository _audit;

  @override
  Future<List<Beneficiary>> beneficiariesOf(String tontineId) =>
      _db.withLatency(() {
        final List<Beneficiary> list = _db.beneficiaries
            .where((Beneficiary b) => b.tontineId == tontineId)
            .toList();
        list.sort(
          (Beneficiary a, Beneficiary b) =>
              a.designatedAt.compareTo(b.designatedAt),
        );
        return List<Beneficiary>.unmodifiable(list);
      });

  @override
  Future<Beneficiary?> beneficiaryOfCycle(String cycleId) =>
      _db.withLatency(() => _db.beneficiaryOfCycle(cycleId));

  @override
  Future<Beneficiary> beneficiaryById(String beneficiaryId) => _db.withLatency(
    () => _db.beneficiaries.firstWhere(
      (Beneficiary b) => b.id == beneficiaryId,
      orElse: () => throw NotFoundException('beneficiary:$beneficiaryId'),
    ),
  );

  @override
  Future<Beneficiary> designateManually({
    required String cycleId,
    required String participantId,
    required String actorMemberId,
  }) async {
    final Beneficiary beneficiary = await _db.withLatency(() {
      final TontineCycle cycle = _db.cycleById(cycleId);
      if (_db.beneficiaryOfCycle(cycleId) != null) {
        // Contrainte forte : un seul bénéficiaire par cycle.
        throw const BusinessRuleException('cycle_already_has_beneficiary');
      }
      final Tontine tontine = _db.tontineById(cycle.tontineId);
      final TontineParticipant participant = _db.participantById(participantId);
      if (participant.hasReceivedPot) {
        throw const BusinessRuleException('participant_already_received');
      }
      final Beneficiary created = Beneficiary(
        id: _db.nextId('ben'),
        organizationId: tontine.organizationId,
        tontineId: tontine.id,
        cycleId: cycle.id,
        participantId: participant.id,
        memberId: participant.memberId,
        memberName: participant.displayName,
        amount: cycle.expectedAmount,
        designatedAt: DateTime.now(),
        source: tontine.allocationMode == AllocationMode.fullOrderDraw
            ? BeneficiarySource.orderDraw
            : BeneficiarySource.manualOrder,
      );
      _db.beneficiaries.add(created);
      _db.replaceParticipant(
        participant.markAsBeneficiary(
          cycleId: cycle.id,
          periodStart: cycle.periodStart,
        ),
      );
      _db.replaceCycle(
        cycle.copyWith(
          status: CycleStatus.drawn,
          beneficiaryParticipantId: participant.id,
          beneficiaryId: created.id,
        ),
      );
      return created;
    });

    await _audit.record(
      organizationId: beneficiary.organizationId,
      action: AuditAction.beneficiaryDesignated,
      description:
          '${beneficiary.memberName} a été désigné(e) bénéficiaire du cycle.',
      actorMemberId: actorMemberId,
      tontineId: beneficiary.tontineId,
      targetType: 'beneficiary',
      targetId: beneficiary.id,
      amount: beneficiary.amount,
    );
    return beneficiary;
  }

  @override
  Future<Payout?> payoutOfCycle(String cycleId) =>
      _db.withLatency(() => _db.payoutOfCycle(cycleId));

  @override
  Future<List<Payout>> payoutsOf(String tontineId) => _db.withLatency(() {
    final List<Payout> list = _db.payouts
        .where((Payout p) => p.tontineId == tontineId)
        .toList();
    list.sort((Payout a, Payout b) => b.createdAt.compareTo(a.createdAt));
    return List<Payout>.unmodifiable(list);
  });

  @override
  Future<Payout> record({
    required PayoutDraft draft,
    required String actorMemberId,
  }) async {
    if (draft.amount <= 0) {
      throw const ValidationException('amount_must_be_positive');
    }
    final Payout payout = await _db.withLatency(() {
      final Beneficiary beneficiary = _db.beneficiaries.firstWhere(
        (Beneficiary b) => b.id == draft.beneficiaryId,
        orElse: () =>
            throw NotFoundException('beneficiary:${draft.beneficiaryId}'),
      );
      final Payout? existing = _db.payoutOfCycle(beneficiary.cycleId);
      if (existing != null && existing.isPaid) {
        throw const BusinessRuleException('payout_already_recorded');
      }
      final Payout created = Payout(
        id: _db.nextId('pay'),
        organizationId: beneficiary.organizationId,
        tontineId: beneficiary.tontineId,
        cycleId: beneficiary.cycleId,
        beneficiaryId: beneficiary.id,
        memberId: beneficiary.memberId,
        memberName: beneficiary.memberName,
        amount: draft.amount,
        status: draft.status,
        method: draft.method,
        reference: draft.reference,
        comment: draft.comment,
        attachmentId: draft.attachmentId,
        sentAt: draft.sentAt,
        recordedBy: actorMemberId,
        createdAt: DateTime.now(),
      );
      _db.payouts.add(created);
      _db.replaceBeneficiary(beneficiary.copyWith(payoutId: created.id));
      final TontineCycle cycle = _db.cycleById(beneficiary.cycleId);
      _db.replaceCycle(
        cycle.copyWith(
          status: created.status == PayoutStatus.paid
              ? CycleStatus.closed
              : CycleStatus.paidOut,
          payoutId: created.id,
        ),
      );
      return created;
    });

    final Tontine tontine = _db.tontineById(payout.tontineId);
    await _audit.record(
      organizationId: payout.organizationId,
      action: AuditAction.payoutRecorded,
      description:
          'Versement de ${MoneyFormatter.format(payout.amount, tontine.currency)} '
          'à ${payout.memberName} enregistré.',
      actorMemberId: actorMemberId,
      tontineId: payout.tontineId,
      targetType: 'payout',
      targetId: payout.id,
      amount: payout.amount,
    );
    return payout;
  }

  @override
  Future<double> totalReceivedBy({
    required String organizationId,
    required String memberId,
  }) => _db.withLatency(
    () => _db.payouts
        .where(
          (Payout p) =>
              p.organizationId == organizationId &&
              p.memberId == memberId &&
              p.isPaid,
        )
        .fold<double>(0, (double sum, Payout p) => sum + p.amount),
  );
}
