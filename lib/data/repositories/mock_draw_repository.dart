import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/utils/period_label.dart';
import 'package:kadjane/core/utils/random_source.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/notification_type.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';
import 'package:kadjane/domain/services/draw_engine.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Moteur de tirage branché sur la base mock.
///
/// Le bénéficiaire est déterminé par [DrawEngine] avant toute animation.
/// TODO(api): déléguer au backend (POST /tontines/{id}/draws) et ne conserver
/// ici que la lecture des sessions.
class MockDrawRepository implements DrawRepository {
  MockDrawRepository(
    this._db,
    this._audit, [
    RandomSource? randomSource,
    this._engine = const DrawEngine(),
    this._rules = const TontineRulesService(),
  ]) : _random = randomSource ?? SecureRandomSource();

  final MockDatabase _db;
  final AuditRepository _audit;
  final DrawEngine _engine;
  final TontineRulesService _rules;
  final RandomSource _random;

  @override
  Future<DrawEligibility> eligibility({
    required String tontineId,
    required String cycleId,
  }) => _db.withLatency(() => _evaluate(tontineId, cycleId));

  @override
  Future<DrawSession> run(RunDrawCommand command) async {
    final DrawSession draw = await _db.withLatency(() {
      final Tontine tontine = _db.tontineById(command.tontineId);
      final TontineCycle cycle = _db.cycleById(command.cycleId);
      final Organization organization = _db.organizationById(
        tontine.organizationId,
      );

      final DrawEligibility eligibility = _evaluate(tontine.id, cycle.id);
      if (!eligibility.allowed) {
        final bool forcible =
            eligibility.reason == DrawBlockReason.missingContributions &&
            command.override &&
            organization.settings.allowDrawOverride;
        if (!forcible) {
          throw BusinessRuleException(
            'draw_not_allowed',
            code: eligibility.reason.name,
            details: <String, Object?>{
              'missing': eligibility.missingContributions,
            },
          );
        }
      }

      final List<TontineParticipant> eligibleParticipants = _rules
          .eligibleForDraw(_db.participantsOf(tontine.id));
      final List<DrawParticipant> candidates = eligibleParticipants
          .map(
            (TontineParticipant p) => DrawParticipant(
              participantId: p.id,
              memberId: p.memberId,
              displayName: p.displayName,
            ),
          )
          .toList(growable: false);

      final RandomSource source = command.seed != null
          ? SeededRandomSource(command.seed!)
          : _random;
      final DateTime executedAt = DateTime.now();
      final DrawOutcome outcome = _engine.draw(
        candidates: candidates,
        random: source,
        at: executedAt,
      );

      final DrawSession session = DrawSession(
        id: _db.nextId('drw'),
        organizationId: tontine.organizationId,
        tontineId: tontine.id,
        cycleId: cycle.id,
        periodLabel: PeriodLabel.monthYear(cycle.periodStart),
        participants: outcome.candidates,
        status: DrawStatus.completed,
        createdAt: executedAt,
        scheduledAt: cycle.drawScheduledAt ?? executedAt,
        executedAt: executedAt,
        winnerParticipantId: outcome.winner.participantId,
        winnerMemberId: outcome.winner.memberId,
        winnerName: outcome.winner.displayName,
        launchedByMemberId: command.actorMemberId,
        launchedByName: _db.memberById(command.actorMemberId).fullName,
        proofReference: outcome.proofReference,
        randomSourceLabel: outcome.randomSourceLabel,
        seed: outcome.seed,
        overrideUsed: command.override,
        overrideReason: command.overrideReason,
      );
      _db.draws.add(session);

      final Beneficiary beneficiary = Beneficiary(
        id: _db.nextId('ben'),
        organizationId: tontine.organizationId,
        tontineId: tontine.id,
        cycleId: cycle.id,
        participantId: outcome.winner.participantId,
        memberId: outcome.winner.memberId,
        memberName: outcome.winner.displayName,
        amount: cycle.expectedAmount,
        designatedAt: executedAt,
        source: BeneficiarySource.periodicDraw,
        drawSessionId: session.id,
      );
      _db.beneficiaries.add(beneficiary);

      // Le bénéficiaire sort de la roue mais reste membre cotisant.
      _db.replaceParticipant(
        _db
            .participantById(outcome.winner.participantId)
            .markAsBeneficiary(
              cycleId: cycle.id,
              periodStart: cycle.periodStart,
            ),
      );
      _db.replaceCycle(
        cycle.copyWith(
          status: CycleStatus.drawn,
          beneficiaryParticipantId: outcome.winner.participantId,
          beneficiaryId: beneficiary.id,
          drawSessionId: session.id,
        ),
      );

      _notifyWinner(session, beneficiary);
      return session;
    });

    await _audit.record(
      organizationId: draw.organizationId,
      action: AuditAction.drawCompleted,
      description:
          '${draw.winnerName} a été tiré(e) comme bénéficiaire de '
          '${draw.periodLabel}.',
      actorMemberId: draw.launchedByMemberId,
      tontineId: draw.tontineId,
      targetType: 'draw',
      targetId: draw.id,
      metadata: <String, Object?>{
        'proof': draw.proofReference,
        'eligible': draw.eligibleCount,
        'source': draw.randomSourceLabel,
      },
    );
    if (draw.overrideUsed) {
      await _audit.record(
        organizationId: draw.organizationId,
        action: AuditAction.drawOverridden,
        description:
            'Le tirage de ${draw.periodLabel} a été forcé malgré des '
            'cotisations manquantes. Motif : '
            '${draw.overrideReason ?? 'non précisé'}.',
        actorMemberId: draw.launchedByMemberId,
        tontineId: draw.tontineId,
        targetType: 'draw',
        targetId: draw.id,
      );
    }
    return draw;
  }

  @override
  Future<DrawSession> generateFullOrder({
    required String tontineId,
    required String actorMemberId,
    int? seed,
  }) async {
    final DrawSession draw = await _db.withLatency(() {
      final Tontine tontine = _db.tontineById(tontineId);
      final List<TontineParticipant> participants = _db.participantsOf(
        tontineId,
      );
      if (participants.any((TontineParticipant p) => p.orderPosition != null)) {
        throw const BusinessRuleException('order_already_defined');
      }
      final List<DrawParticipant> candidates = participants
          .map(
            (TontineParticipant p) => DrawParticipant(
              participantId: p.id,
              memberId: p.memberId,
              displayName: p.displayName,
            ),
          )
          .toList(growable: false);
      final RandomSource source = seed != null
          ? SeededRandomSource(seed)
          : _random;
      final List<DrawParticipant> ordered = _engine.generateOrder(
        participants: candidates,
        random: source,
      );
      for (int i = 0; i < ordered.length; i++) {
        _db.replaceParticipant(
          _db
              .participantById(ordered[i].participantId)
              .copyWith(orderPosition: i + 1),
        );
      }
      final DateTime now = DateTime.now();
      final List<TontineCycle> cycles = _db.cyclesOf(tontineId);
      final DrawSession session = DrawSession(
        id: _db.nextId('drw'),
        organizationId: tontine.organizationId,
        tontineId: tontineId,
        cycleId: cycles.isEmpty ? '' : cycles.first.id,
        periodLabel: cycles.isEmpty
            ? ''
            : PeriodLabel.monthYear(cycles.first.periodStart),
        participants: ordered,
        status: DrawStatus.completed,
        createdAt: now,
        executedAt: now,
        scheduledAt: now,
        winnerParticipantId: ordered.first.participantId,
        winnerMemberId: ordered.first.memberId,
        winnerName: ordered.first.displayName,
        launchedByMemberId: actorMemberId,
        launchedByName: _db.memberById(actorMemberId).fullName,
        proofReference: _engine.buildProofReference(
          candidates: ordered,
          winnerId: ordered.first.participantId,
          at: now,
        ),
        randomSourceLabel: source.label,
        seed: seed,
      );
      _db.draws.add(session);
      return session;
    });

    await _audit.record(
      organizationId: draw.organizationId,
      action: AuditAction.orderGenerated,
      description:
          'L\'ordre de passage complet a été tiré au sort '
          '(${draw.participants.length} participants).',
      actorMemberId: actorMemberId,
      tontineId: tontineId,
      targetType: 'draw',
      targetId: draw.id,
    );
    return draw;
  }

  @override
  Future<List<DrawSession>> historyOf(String tontineId) => _db.withLatency(() {
    final List<DrawSession> sessions = _db.draws
        .where((DrawSession d) => d.tontineId == tontineId)
        .toList();
    sessions.sort(
      (DrawSession a, DrawSession b) => b.createdAt.compareTo(a.createdAt),
    );
    return List<DrawSession>.unmodifiable(sessions);
  });

  @override
  Future<DrawSession> byId(String drawId) => _db.withLatency(
    () => _db.draws.firstWhere(
      (DrawSession d) => d.id == drawId,
      orElse: () => throw NotFoundException('draw:$drawId'),
    ),
  );

  @override
  Future<DrawSession?> forCycle(String cycleId) =>
      _db.withLatency(() => _db.drawOfCycle(cycleId));

  @override
  Future<DrawSession> cancel({
    required String drawId,
    required String reason,
    required String actorMemberId,
  }) async {
    final DrawSession updated = await _db.withLatency(() {
      final DrawSession draw = _db.draws.firstWhere(
        (DrawSession d) => d.id == drawId,
        orElse: () => throw NotFoundException('draw:$drawId'),
      );
      if (draw.status == DrawStatus.completed) {
        throw const BusinessRuleException('completed_draw_must_be_invalidated');
      }
      final DrawSession next = draw.copyWith(
        status: DrawStatus.cancelled,
        closedAt: DateTime.now(),
        closeReason: reason,
      );
      _db.replaceDraw(next);
      return next;
    });
    await _audit.record(
      organizationId: updated.organizationId,
      action: AuditAction.drawCancelled,
      description:
          'Le tirage ${updated.proofReference} a été annulé ($reason).',
      actorMemberId: actorMemberId,
      tontineId: updated.tontineId,
      targetType: 'draw',
      targetId: updated.id,
    );
    return updated;
  }

  @override
  Future<DrawSession> invalidate({
    required String drawId,
    required String reason,
    required String actorMemberId,
  }) async {
    final DrawSession updated = await _db.withLatency(() {
      final DrawSession draw = _db.draws.firstWhere(
        (DrawSession d) => d.id == drawId,
        orElse: () => throw NotFoundException('draw:$drawId'),
      );
      if (!draw.isCompleted) {
        throw const BusinessRuleException(
          'only_completed_draw_can_be_invalidated',
        );
      }
      final Payout? payout = _db.payoutOfCycle(draw.cycleId);
      if (payout != null && payout.isPaid) {
        // Un versement déjà effectué interdit l'invalidation du tirage.
        throw const BusinessRuleException('payout_already_done');
      }

      // Le tirage n'est jamais supprimé : il est marqué invalidé.
      final DrawSession next = draw.copyWith(
        status: DrawStatus.invalidated,
        closedAt: DateTime.now(),
        closeReason: reason,
      );
      _db.replaceDraw(next);

      if (draw.winnerParticipantId != null) {
        _db.replaceParticipant(
          _db
              .participantById(draw.winnerParticipantId!)
              .resetBeneficiaryStatus(),
        );
      }
      _db.beneficiaries.removeWhere(
        (Beneficiary b) => b.drawSessionId == draw.id,
      );
      _db.replaceCycle(_db.cycleById(draw.cycleId).clearBeneficiary());
      return next;
    });

    await _audit.record(
      organizationId: updated.organizationId,
      action: AuditAction.drawInvalidated,
      description:
          'Le tirage ${updated.proofReference} de ${updated.periodLabel} a été '
          'invalidé ($reason). Le bénéficiaire redevient éligible.',
      actorMemberId: actorMemberId,
      tontineId: updated.tontineId,
      targetType: 'draw',
      targetId: updated.id,
    );
    return updated;
  }

  // --- Interne -------------------------------------------------------------

  DrawEligibility _evaluate(String tontineId, String cycleId) {
    final Tontine tontine = _db.tontineById(tontineId);
    final TontineCycle cycle = _db.cycleById(cycleId);
    final Organization organization = _db.organizationById(
      tontine.organizationId,
    );
    if (tontine.allocationMode.hasPredefinedOrder) {
      return const DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.orderAlreadyDefined,
        missingContributions: 0,
        canOverride: false,
      );
    }
    return _rules.evaluateDraw(
      tontine: tontine,
      cycle: cycle,
      settings: organization.settings,
      participants: _db.participantsOf(tontineId),
      contributions: _db.contributionsOfCycle(cycleId),
    );
  }

  void _notifyWinner(DrawSession session, Beneficiary beneficiary) {
    final String? userId = _userIdOfMember(beneficiary.memberId);
    if (userId == null) {
      return;
    }
    _db.notifications.add(
      AppNotification(
        id: _db.nextId('ntf'),
        userId: userId,
        organizationId: session.organizationId,
        type: NotificationType.drawResult,
        title: 'Résultat du tirage',
        body:
            'Vous êtes le bénéficiaire de ${session.periodLabel}. '
            'Référence : ${session.proofReference}.',
        createdAt: DateTime.now(),
        data: <String, String>{
          'tontineId': session.tontineId,
          'cycleId': session.cycleId,
        },
      ),
    );
  }

  String? _userIdOfMember(String memberId) {
    try {
      return _db.memberById(memberId).userId;
    } on NotFoundException {
      return null;
    }
  }
}
