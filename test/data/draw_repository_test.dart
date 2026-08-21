import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

import '../helpers/test_context.dart';

void main() {
  late TestContext ctx;

  setUp(() => ctx = TestContext());

  Future<void> payRemainingContributions() async {
    final List<ContributionSlot> slots = await ctx.contributions.slotsForCycle(
      ctx.currentCycle.id,
    );
    for (final ContributionSlot slot in slots.where(
      (ContributionSlot s) => !s.isPaid,
    )) {
      await ctx.contributions.record(
        actorMemberId: ctx.treasurer.id,
        draft: ContributionDraft(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
          memberId: slot.memberId,
          amount: slot.expectedAmount,
          method: PaymentMethod.cash,
        ),
      );
    }
  }

  group('Conditions du tirage', () {
    test('le tirage est bloqué tant qu\'une cotisation manque', () async {
      final DrawEligibility eligibility = await ctx.draws.eligibility(
        tontineId: ctx.monthlyDrawTontine.id,
        cycleId: ctx.currentCycle.id,
      );

      expect(eligibility.allowed, isFalse);
      expect(eligibility.reason, DrawBlockReason.missingContributions);
      expect(eligibility.missingContributions, 1);

      expect(
        () => ctx.draws.run(
          RunDrawCommand(
            tontineId: ctx.monthlyDrawTontine.id,
            cycleId: ctx.currentCycle.id,
            actorMemberId: ctx.admin.id,
          ),
        ),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('le forçage est possible et laisse une trace d\'audit', () async {
      final DrawSession session = await ctx.draws.run(
        RunDrawCommand(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
          actorMemberId: ctx.admin.id,
          override: true,
          overrideReason: 'Décision du bureau',
        ),
      );

      expect(session.overrideUsed, isTrue);
      expect(session.status, DrawStatus.completed);

      final List<AuditLog> logs = await ctx.audit.list(
        organizationId: session.organizationId,
      );
      expect(
        logs.where((AuditLog log) => log.action == AuditAction.drawOverridden),
        isNotEmpty,
      );
    });

    test(
      'le tirage est autorisé une fois toutes les cotisations reçues',
      () async {
        await payRemainingContributions();

        final DrawEligibility eligibility = await ctx.draws.eligibility(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
        );
        expect(eligibility.allowed, isTrue);

        final DrawSession session = await ctx.draws.run(
          RunDrawCommand(
            tontineId: ctx.monthlyDrawTontine.id,
            cycleId: ctx.currentCycle.id,
            actorMemberId: ctx.admin.id,
          ),
        );

        expect(session.status, DrawStatus.completed);
        expect(session.winnerParticipantId, isNotNull);
        expect(session.proofReference, startsWith('KDJ-'));
        expect(session.overrideUsed, isFalse);
      },
    );
  });

  group('Effets du tirage', () {
    test('le gagnant quitte la roue mais reste cotisant', () async {
      await payRemainingContributions();
      final int eligibleBefore = const TontineRulesService()
          .eligibleForDraw(
            await ctx.tontines.participants(ctx.monthlyDrawTontine.id),
          )
          .length;

      final DrawSession session = await ctx.draws.run(
        RunDrawCommand(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
          actorMemberId: ctx.admin.id,
        ),
      );

      final List<TontineParticipant> participants = await ctx.tontines
          .participants(ctx.monthlyDrawTontine.id);
      final TontineParticipant winner = participants.firstWhere(
        (TontineParticipant p) => p.id == session.winnerParticipantId,
      );

      expect(winner.hasReceivedPot, isTrue);
      expect(winner.isEligibleForDraw, isFalse);
      // Règle fondamentale : sortir de la roue ≠ sortir de la tontine.
      expect(winner.isActive, isTrue);
      expect(winner.mustKeepContributing, isTrue);

      final int eligibleAfter = const TontineRulesService()
          .eligibleForDraw(participants)
          .length;
      expect(eligibleAfter, eligibleBefore - 1);
    });

    test('un cycle ne peut pas avoir deux bénéficiaires', () async {
      await payRemainingContributions();
      await ctx.draws.run(
        RunDrawCommand(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
          actorMemberId: ctx.admin.id,
        ),
      );

      // Un second tirage est refusé...
      expect(
        () => ctx.draws.run(
          RunDrawCommand(
            tontineId: ctx.monthlyDrawTontine.id,
            cycleId: ctx.currentCycle.id,
            actorMemberId: ctx.admin.id,
          ),
        ),
        throwsA(isA<BusinessRuleException>()),
      );

      // ...et une désignation manuelle aussi.
      final List<TontineParticipant> eligible = const TontineRulesService()
          .eligibleForDraw(
            await ctx.tontines.participants(ctx.monthlyDrawTontine.id),
          );
      expect(
        () => ctx.payouts.designateManually(
          cycleId: ctx.currentCycle.id,
          participantId: eligible.first.id,
          actorMemberId: ctx.admin.id,
        ),
        throwsA(isA<BusinessRuleException>()),
      );

      final List<Beneficiary> beneficiaries = await ctx.payouts.beneficiariesOf(
        ctx.monthlyDrawTontine.id,
      );
      expect(
        beneficiaries
            .where((Beneficiary b) => b.cycleId == ctx.currentCycle.id)
            .length,
        1,
      );
    });
  });

  group('Intégrité des sessions', () {
    test('un tirage validé ne peut pas être annulé directement', () async {
      await payRemainingContributions();
      final DrawSession session = await ctx.draws.run(
        RunDrawCommand(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
          actorMemberId: ctx.admin.id,
        ),
      );

      expect(
        () => ctx.draws.cancel(
          drawId: session.id,
          reason: 'Erreur de saisie',
          actorMemberId: ctx.admin.id,
        ),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test(
      'l\'invalidation conserve la session et libère le bénéficiaire',
      () async {
        await payRemainingContributions();
        final DrawSession session = await ctx.draws.run(
          RunDrawCommand(
            tontineId: ctx.monthlyDrawTontine.id,
            cycleId: ctx.currentCycle.id,
            actorMemberId: ctx.admin.id,
          ),
        );

        final DrawSession invalidated = await ctx.draws.invalidate(
          drawId: session.id,
          reason: 'Contestation du bureau',
          actorMemberId: ctx.admin.id,
        );

        expect(invalidated.status, DrawStatus.invalidated);
        expect(invalidated.closeReason, 'Contestation du bureau');

        // La session reste dans l'historique : aucune suppression.
        final List<DrawSession> history = await ctx.draws.historyOf(
          ctx.monthlyDrawTontine.id,
        );
        expect(
          history.where((DrawSession d) => d.id == session.id),
          isNotEmpty,
        );

        // Le participant redevient éligible et le cycle repart en collecte.
        final List<TontineParticipant> participants = await ctx.tontines
            .participants(ctx.monthlyDrawTontine.id);
        final TontineParticipant former = participants.firstWhere(
          (TontineParticipant p) => p.id == session.winnerParticipantId,
        );
        expect(former.isEligibleForDraw, isTrue);
        expect(former.hasReceivedPot, isFalse);

        final TontineCycle cycle = await ctx.tontines.cycleById(
          ctx.currentCycle.id,
        );
        expect(cycle.beneficiaryParticipantId, isNull);

        final List<AuditLog> logs = await ctx.audit.list(
          organizationId: session.organizationId,
        );
        expect(
          logs.where(
            (AuditLog log) => log.action == AuditAction.drawInvalidated,
          ),
          isNotEmpty,
        );
      },
    );

    test(
      'les tontines à ordre prédéfini n\'ouvrent pas de tirage périodique',
      () async {
        final List<TontineCycle> cycles = await ctx.tontines.cycles(
          ctx.fullOrderTontine.id,
        );
        final DrawEligibility eligibility = await ctx.draws.eligibility(
          tontineId: ctx.fullOrderTontine.id,
          cycleId: cycles[1].id,
        );

        expect(eligibility.allowed, isFalse);
        expect(eligibility.reason, DrawBlockReason.orderAlreadyDefined);
      },
    );
  });

  group('Cotisations', () {
    test('une cotisation annulée sort du montant collecté', () async {
      final String cycleId = ctx.currentCycle.id;
      final List<Contribution> before = await ctx.contributions.forCycle(
        cycleId,
      );
      const TontineRulesService rules = TontineRulesService();
      final double collectedBefore = rules.collectedAmount(before);

      final Contribution target = before.firstWhere(
        (Contribution c) => c.countsAsCollected,
      );
      await ctx.contributions.cancel(
        contributionId: target.id,
        reason: 'Virement rejeté',
        actorMemberId: ctx.treasurer.id,
      );

      final List<Contribution> after = await ctx.contributions.forCycle(
        cycleId,
      );
      expect(rules.collectedAmount(after), collectedBefore - target.amount);
      // La ligne reste dans l'historique.
      expect(after.length, before.length);
      expect(
        after.firstWhere((Contribution c) => c.id == target.id).status,
        ContributionStatus.cancelled,
      );
    });
  });
}
