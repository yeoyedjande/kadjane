@Tags(<String>['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/remote/http_api_client.dart';
import 'package:kadjane/data/repositories/rest_auth_repository.dart';
import 'package:kadjane/data/repositories/rest_contribution_repository.dart';
import 'package:kadjane/data/repositories/rest_draw_repository.dart';
import 'package:kadjane/data/repositories/rest_member_repository.dart';
import 'package:kadjane/data/repositories/rest_organization_repository.dart';
import 'package:kadjane/data/repositories/rest_payout_repository.dart';
import 'package:kadjane/data/repositories/rest_support_repositories.dart';
import 'package:kadjane/data/repositories/rest_tontine_repository.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';
import 'package:kadjane/domain/repositories/payout_repository.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Parcours complet contre le backend réel, avec la pile REST de production.
///
/// Prérequis :
///
///     docker compose up -d
///     docker compose exec backend python -m app.db.seed
///
/// Lancement (ignoré sans le drapeau, pour que `flutter test` reste
/// indépendant d'un serveur) :
///
///     flutter test test/integration/live_api_test.dart \
///       --dart-define=KADJANE_LIVE_API=true
void main() {
  const bool enabled = bool.fromEnvironment('KADJANE_LIVE_API');
  const String baseUrl = String.fromEnvironment(
    'KADJANE_API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  const String password = String.fromEnvironment(
    'KADJANE_DEMO_PASSWORD',
    defaultValue: 'kadjane',
  );
  const String? skipReason = enabled
      ? null
      : 'définir KADJANE_LIVE_API=true pour lancer ce test';

  late InMemoryTokenStore tokens;
  late InMemoryKeyValueStore store;
  late HttpApiClient api;

  setUp(() {
    tokens = InMemoryTokenStore();
    store = InMemoryKeyValueStore();
    api = HttpApiClient(tokenStore: tokens, baseUrl: baseUrl);
  });

  tearDown(() => api.close());

  Future<AuthSession> signIn() => RestAuthRepository(
    api,
    tokens,
    store,
  ).signIn(identifier: 'yeo@kadjane.app', password: password);

  test(
    'identité, organisation et membres viennent de PostgreSQL',
    () async {
      final AuthSession session = await signIn();
      // Identité vérifiée sur la clé de connexion, pas sur le nom affiché :
      // celui-ci est modifiable depuis l'application, et une base seedée de
      // longue date dérive du contenu de `app/db/seed.py`.
      expect(session.user.email, 'yeo@kadjane.app');
      expect(session.user.phone, '+225 07 00 00 00 01');

      final RestOrganizationRepository organizations =
          RestOrganizationRepository(api);
      final List<Organization> mine = await organizations.organizationsOf(
        session.user.id,
      );
      final Organization active = mine.firstWhere(
        (Organization o) => o.name == 'Association Solidarité',
      );

      final OrganizationMember membership = await organizations.membershipOf(
        organizationId: active.id,
        userId: session.user.id,
      );
      expect(membership.role.code, 'admin');

      // Au moins les douze membres du seed ; le back-office peut en avoir
      // ajouté d'autres entre-temps, ce qui reste un succès.
      final PagedResult<OrganizationMember> members =
          await RestMemberRepository(
            api,
          ).list(organizationId: active.id, pageSize: 50);
      expect(members.total, greaterThanOrEqualTo(12));
      expect(
        members.items.map((OrganizationMember m) => m.user.lastName),
        containsAll(<String>['YEO', 'KOUASSI', 'KOFFI']),
      );

      final DashboardSnapshot dashboard = await RestDashboardRepository(
        api,
      ).load(organizationId: active.id, memberId: membership.id);
      expect(dashboard.membersCount, members.total);
      expect(dashboard.activeTontines, greaterThanOrEqualTo(1));
    },
    skip: skipReason,
  );

  test(
    'parcours complet : cotisations, tirage serveur, bénéficiaire, versement',
    () async {
      final AuthSession session = await signIn();
      final RestOrganizationRepository organizations =
          RestOrganizationRepository(api);
      final Organization active =
          (await organizations.organizationsOf(session.user.id)).firstWhere(
            (Organization o) => o.name == 'Association Solidarité',
          );
      final OrganizationMember me = await organizations.membershipOf(
        organizationId: active.id,
        userId: session.user.id,
      );

      final RestTontineRepository tontines = RestTontineRepository(api);
      final RestContributionRepository contributions =
          RestContributionRepository(api);
      final RestDrawRepository draws = RestDrawRepository(api);
      final RestPayoutRepository payouts = RestPayoutRepository(api);

      // --- Tontine et cagnotte ---------------------------------------------
      final TontineSummary summary = (await tontines.list(
        organizationId: active.id,
      )).firstWhere((TontineSummary s) => s.tontine.name == 'Tontine Solidarité');

      // Les participants sont figés à la création : ajouter un membre à
      // l'organisation ne l'inscrit pas rétroactivement à la tontine.
      expect(summary.participantCount, 12);
      expect(summary.totalCycles, 12);
      // 12 × 50 000, calculé par le serveur.
      expect(summary.pot, 600000);

      // --- Cycle ouvert ------------------------------------------------------
      final List<TontineCycle> cycles = await tontines.cycles(
        summary.tontine.id,
      );
      final TontineCycle cycle = cycles.firstWhere(
        (TontineCycle c) => !c.status.hasBeneficiary,
      );
      expect(cycle.expectedAmount, 600000);

      // --- Cotisations -------------------------------------------------------
      final List<ContributionSlot> slots = await contributions.slotsForCycle(
        cycle.id,
      );
      expect(slots, hasLength(12));

      for (final ContributionSlot slot in slots.where(
        (ContributionSlot s) => !s.isPaid,
      )) {
        await contributions.record(
          draft: ContributionDraft(
            tontineId: summary.tontine.id,
            cycleId: cycle.id,
            memberId: slot.memberId,
            amount: slot.expectedAmount,
            method: PaymentMethod.cash,
          ),
          actorMemberId: me.id,
        );
      }

      final TontineCycle collected = await tontines.cycleById(cycle.id);
      expect(collected.status, CycleStatus.readyForDraw);

      // --- Tirage : le serveur décide ---------------------------------------
      final DrawEligibility eligibility = await draws.eligibility(
        tontineId: summary.tontine.id,
        cycleId: cycle.id,
      );
      expect(eligibility.allowed, isTrue);

      final DrawSession drawn = await draws.run(
        RunDrawCommand(
          tontineId: summary.tontine.id,
          cycleId: cycle.id,
          actorMemberId: me.id,
        ),
      );
      expect(drawn.status.isBinding, isTrue);
      expect(drawn.winnerParticipantId, isNotNull);
      expect(drawn.randomSourceLabel, 'server_secrets_choice');
      // La roue s'aligne sur la liste scellée par le serveur.
      expect(
        drawn.participants.map((DrawParticipant p) => p.participantId),
        contains(drawn.winnerParticipantId),
      );

      // Un second tirage est refusé.
      await expectLater(
        draws.run(
          RunDrawCommand(
            tontineId: summary.tontine.id,
            cycleId: cycle.id,
            actorMemberId: me.id,
          ),
        ),
        throwsA(isA<Exception>()),
      );

      // --- Bénéficiaire et versement ----------------------------------------
      final Beneficiary? beneficiary = await payouts.beneficiaryOfCycle(
        cycle.id,
      );
      expect(beneficiary, isNotNull);
      expect(beneficiary!.amount, 600000);
      expect(beneficiary.memberName, drawn.winnerName);

      final Payout payout = await payouts.record(
        draft: PayoutDraft(
          beneficiaryId: beneficiary.id,
          amount: beneficiary.amount,
          method: PaymentMethod.wave,
          sentAt: DateTime.now(),
          reference: 'WV-LIVE',
        ),
        actorMemberId: me.id,
      );
      expect(payout.status, PayoutStatus.paid);

      final TontineCycle closed = await tontines.cycleById(cycle.id);
      expect(closed.status, CycleStatus.paidOut);

      // --- Après le tirage ---------------------------------------------------
      final List<TontineParticipant> participants = await tontines.participants(
        summary.tontine.id,
      );
      final TontineParticipant winner = participants.firstWhere(
        (TontineParticipant p) => p.id == drawn.winnerParticipantId,
      );
      expect(winner.hasReceivedPot, isTrue);
      expect(winner.isEligibleForDraw, isFalse);
      // Règle centrale : il reste dans la tontine.
      expect(winner.isActive, isTrue);

      final TontineCycle next = (await tontines.cycles(
        summary.tontine.id,
      )).firstWhere((TontineCycle c) => c.index == cycle.index + 1);

      final List<ContributionSlot> nextSlots = await contributions
          .slotsForCycle(next.id);
      expect(nextSlots, hasLength(12));
      expect(
        nextSlots.where(
          (ContributionSlot s) => s.memberName == drawn.winnerName,
        ),
        hasLength(1),
        reason: 'l\'ancien bénéficiaire continue de cotiser',
      );

      final DrawEligibility nextWheel = await draws.eligibility(
        tontineId: summary.tontine.id,
        cycleId: next.id,
      );
      expect(nextWheel.allowed, isFalse);
      expect(nextWheel.reason, DrawBlockReason.missingContributions);

      // --- Persistance : nouvelle session, mêmes données --------------------
      final InMemoryTokenStore freshTokens = InMemoryTokenStore();
      final HttpApiClient freshApi = HttpApiClient(
        tokenStore: freshTokens,
        baseUrl: baseUrl,
      );
      addTearDown(freshApi.close);
      await RestAuthRepository(
        freshApi,
        freshTokens,
        InMemoryKeyValueStore(),
      ).signIn(identifier: 'yeo@kadjane.app', password: password);

      final Beneficiary? persisted = await RestPayoutRepository(
        freshApi,
      ).beneficiaryOfCycle(cycle.id);
      expect(persisted?.memberName, drawn.winnerName);
    },
    skip: skipReason,
  );
}
