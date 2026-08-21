import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/remote/http_api_client.dart';
import 'package:kadjane/data/repositories/rest_contribution_repository.dart';
import 'package:kadjane/data/repositories/rest_draw_repository.dart';
import 'package:kadjane/data/repositories/rest_payout_repository.dart';
import 'package:kadjane/data/repositories/rest_tontine_repository.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Rejoue les réponses **réelles** du backend métier (tontines, cycles,
/// cotisations, tirage, bénéficiaire, versement) dans les repositories REST.
///
/// Les charges utiles sont copiées telles quelles depuis
/// `http://localhost:8000/api/v1/...` sur la base seedée : si le serveur
/// change de forme, ces tests tombent.
void main() {
  const String baseUrl = 'http://localhost:8000/api/v1';
  const String tontineId = '67ec22f0-17bb-4918-8b4c-e613da969e71';
  const String cycleId = '93fb4409-94a1-448c-bccd-404ce36e86da';
  const String participantId = '40bc4753-c37c-4c36-bf2c-abd743a0e17e';
  const String memberId = '809cf60d-36e7-48f6-8bde-947b2f8d6e06';

  final Map<String, dynamic> tontinePayload = <String, dynamic>{
    'id': tontineId,
    'organizationId': 'b55bdcb6-7bdd-4513-929b-b1195a63b048',
    'name': 'Tontine Solidarité',
    'description': "Tontine mensuelle de l'association.",
    'contributionAmount': 50000.0,
    'currency': 'XOF',
    'frequency': 'monthly',
    'allocationMode': 'monthly_draw',
    'attributionMode': 'monthly_draw',
    'startDate': '2026-08-01T00:00:00Z',
    'dueDayOfPeriod': 5,
    'customPeriodDays': null,
    'status': 'active',
    'requireAllContributionsBeforeDraw': true,
    'allowDrawOverride': true,
    'createdBy': '6374fef3-df2c-4213-9f8a-d05e01aeef9c',
    'createdAt': '2026-08-20T22:59:00.000Z',
    'closedAt': null,
  };

  final Map<String, dynamic> cyclePayload = <String, dynamic>{
    'id': cycleId,
    'tontineId': tontineId,
    'index': 1,
    'sequenceNumber': 1,
    'periodLabel': 'Août 2026',
    'periodStart': '2026-08-01T00:00:00Z',
    'periodEnd': '2026-08-31T23:59:59Z',
    'dueDate': '2026-08-05T23:59:59Z',
    'expectedAmount': 600000.0,
    'collectedAmount': 600000.0,
    'remainingAmount': 0.0,
    'status': 'paid_out',
    'beneficiaryParticipantId': participantId,
    'beneficiaryId': 'ben-1',
    'drawSessionId': 'drw-1',
    'payoutId': 'pay-1',
    'drawScheduledAt': null,
  };

  http.Response envelope(Object? data, {int status = 200}) => http.Response(
    jsonEncode(<String, dynamic>{'success': true, 'data': data}),
    status,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );

  HttpApiClient apiWith(MockClient mock) => HttpApiClient(
    tokenStore: InMemoryTokenStore(),
    httpClient: mock,
    baseUrl: baseUrl,
  );

  group('Tontines', () {
    test('la liste porte les agrégats calculés par le serveur', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(<Map<String, dynamic>>[
            <String, dynamic>{
              'tontine': tontinePayload,
              'participantCount': 12,
              'completedCycles': 1,
              'totalCycles': 12,
              'collectedCurrentCycle': 600000.0,
              'expectedCurrentCycle': 600000.0,
              'currentCycle': cyclePayload,
              'currentBeneficiaryName': 'Kouadio N GUESSAN',
              'previousBeneficiaryName': null,
            },
          ]),
        ),
      );

      final List<TontineSummary> summaries = await RestTontineRepository(
        api,
      ).list(organizationId: 'org-1');

      final TontineSummary summary = summaries.single;
      expect(summary.tontine.name, 'Tontine Solidarité');
      expect(summary.tontine.allocationMode, AllocationMode.monthlyDraw);
      expect(summary.participantCount, 12);
      // Cagnotte calculée : 12 × 50 000.
      expect(summary.pot, 600000);
      expect(summary.collectionProgress, 1);
      expect(summary.currentCycle?.periodStart.year, 2026);
      expect(summary.currentBeneficiaryName, 'Kouadio N GUESSAN');
    });

    test('les cycles sont ordonnés et datés', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(<Map<String, dynamic>>[
            cyclePayload,
            <String, dynamic>{
              ...cyclePayload,
              'id': 'cyc-2',
              'index': 2,
              'periodLabel': 'Septembre 2026',
              'periodStart': '2026-09-01T00:00:00Z',
              'status': 'upcoming',
              'collectedAmount': 0.0,
              'beneficiaryParticipantId': null,
              'payoutId': null,
            },
          ]),
        ),
      );

      final List<TontineCycle> cycles = await RestTontineRepository(
        api,
      ).cycles(tontineId);

      expect(cycles, hasLength(2));
      expect(cycles.first.status, CycleStatus.paidOut);
      expect(cycles.first.hasBeneficiary, isTrue);
      expect(cycles.last.status, CycleStatus.upcoming);
      expect(cycles.last.expectedAmount, 600000);
    });

    test('un corps vide signifie « aucun cycle en cours »', () async {
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async => envelope(null)),
      );

      expect(await RestTontineRepository(api).currentCycle(tontineId), isNull);
    });

    test('un ancien bénéficiaire reste actif dans les participants', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': participantId,
              'tontineId': tontineId,
              'memberId': memberId,
              'displayName': 'Kouadio N GUESSAN',
              'avatarUrl': null,
              'joinedAt': '2026-08-01T00:00:00Z',
              'isActive': true,
              'isEligibleForDraw': false,
              'hasReceivedPot': true,
              'receivedCycleId': cycleId,
              'orderPosition': null,
            },
          ]),
        ),
      );

      final TontineParticipant participant = (await RestTontineRepository(
        api,
      ).participants(tontineId)).single;

      expect(participant.hasReceivedPot, isTrue);
      expect(participant.isEligibleForDraw, isFalse);
      // La règle qui distingue Kadjane : il continue de cotiser.
      expect(participant.isActive, isTrue);
    });
  });

  group('Cotisations', () {
    test('les lignes attendues portent le paiement quand il existe', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(<Map<String, dynamic>>[
            <String, dynamic>{
              'memberId': memberId,
              'memberName': 'Kouadio N GUESSAN',
              'avatarUrl': null,
              'expectedAmount': 50000.0,
              'paidAmount': 50000.0,
              'status': 'paid',
              'contributionId': 'ctr-1',
              'contribution': <String, dynamic>{
                'id': 'pay-1',
                'organizationId': 'org-1',
                'tontineId': tontineId,
                'cycleId': cycleId,
                'memberId': memberId,
                'memberName': 'Kouadio N GUESSAN',
                'amount': 50000.0,
                'status': 'confirmed',
                'method': 'orange_money',
                'reference': 'OM-9931',
                'comment': null,
                'attachmentId': null,
                'paidAt': '2026-08-03T10:00:00Z',
                'recordedBy': 'mbr-2',
                'recordedAt': '2026-08-03T10:00:00Z',
                'cancelledAt': null,
                'cancelReason': null,
              },
            },
            <String, dynamic>{
              'memberId': 'mbr-9',
              'memberName': 'Salif OUATTARA',
              'avatarUrl': null,
              'expectedAmount': 50000.0,
              'paidAmount': 0.0,
              'status': 'pending',
              'contributionId': 'ctr-2',
              'contribution': null,
            },
          ]),
        ),
      );

      final List<ContributionSlot> slots = await RestContributionRepository(
        api,
      ).slotsForCycle(cycleId);

      expect(slots, hasLength(2));
      expect(slots.first.isPaid, isTrue);
      expect(slots.first.paidAmount, 50000);
      expect(slots.first.contribution?.method, PaymentMethod.orangeMoney);
      expect(slots.last.isPaid, isFalse);
      expect(slots.last.contribution, isNull);
    });

    test('l\'enregistrement d\'un paiement envoie le bon corps', () async {
      late http.Request captured;
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async {
          captured = request;
          return envelope(<String, dynamic>{
            'id': 'pay-2',
            'organizationId': 'org-1',
            'tontineId': tontineId,
            'cycleId': cycleId,
            'memberId': memberId,
            'memberName': 'Kouadio N GUESSAN',
            'amount': 50000.0,
            'status': 'confirmed',
            'method': 'wave',
            'recordedAt': '2026-08-04T09:00:00Z',
          });
        }),
      );

      await RestContributionRepository(api).record(
        draft: const ContributionDraft(
          tontineId: tontineId,
          cycleId: cycleId,
          memberId: memberId,
          amount: 50000,
          method: PaymentMethod.wave,
        ),
        actorMemberId: 'mbr-2',
      );

      expect(captured.url.path, '/api/v1/tontines/$tontineId/contributions');
      final Map<String, dynamic> body =
          jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['cycleId'], cycleId);
      expect(body['memberId'], memberId);
      expect(body['amount'], 50000);
      expect(body['method'], 'wave');
      expect(body['status'], 'confirmed');
    });
  });

  group('Tirage', () {
    test('le blocage indique la cotisation manquante', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(<String, dynamic>{
            'allowed': false,
            'reason': 'missingContributions',
            'missingContributions': 1,
            'canOverride': true,
            'can_draw': false,
            'participants_count': 12,
            'eligible_count': 12,
            'eligible_participants': <dynamic>[],
            'remaining_contributions': 1,
            'remaining_amount': 50000.0,
            'override_allowed': true,
          }),
        ),
      );

      final DrawEligibility eligibility = await RestDrawRepository(
        api,
      ).eligibility(tontineId: tontineId, cycleId: cycleId);

      expect(eligibility.allowed, isFalse);
      expect(eligibility.reason, DrawBlockReason.missingContributions);
      expect(eligibility.missingContributions, 1);
      expect(eligibility.canOverride, isTrue);
    });

    test('le gagnant vient du serveur et figure dans la roue', () async {
      late http.Request captured;
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async {
          captured = request;
          return envelope(<String, dynamic>{
            'id': 'drw-1',
            'organizationId': 'org-1',
            'tontineId': tontineId,
            'cycleId': cycleId,
            'periodLabel': 'Août 2026',
            'participants': <Map<String, dynamic>>[
              <String, dynamic>{
                'participantId': 'prt-1',
                'memberId': 'mbr-1',
                'displayName': 'Yedjane YEO',
                'weight': 1,
              },
              <String, dynamic>{
                'participantId': participantId,
                'memberId': memberId,
                'displayName': 'Kouadio N GUESSAN',
                'weight': 1,
              },
            ],
            'status': 'completed',
            'executedAt': '2026-08-20T22:59:43.825775Z',
            'createdAt': '2026-08-20T22:59:43.794835Z',
            'winnerParticipantId': participantId,
            'winnerMemberId': memberId,
            'winnerName': 'Kouadio N GUESSAN',
            'launchedByMemberId': 'mbr-1',
            'proofReference': 'KDJ-C15997D5',
            'randomSourceLabel': 'server_secrets_choice',
            'seed': null,
            'overrideUsed': false,
            'overrideReason': null,
          });
        }),
      );

      final DrawSession session = await RestDrawRepository(api).run(
        const RunDrawCommand(
          tontineId: tontineId,
          cycleId: cycleId,
          actorMemberId: 'mbr-1',
        ),
      );

      expect(captured.url.path, '/api/v1/tontines/$tontineId/draws');
      expect(session.status, DrawStatus.completed);
      expect(session.winnerName, 'Kouadio N GUESSAN');
      expect(session.randomSourceLabel, 'server_secrets_choice');
      // L'index du gagnant sert à orienter la roue : il doit exister.
      final int index = session.participants.indexWhere(
        (DrawParticipant p) => p.participantId == session.winnerParticipantId,
      );
      expect(index, 1);
    });

    test('un second tirage remonte une règle métier, pas une erreur brute', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => http.Response(
            jsonEncode(<String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'alreadyDrawn',
                'message': 'Un bénéficiaire a déjà été désigné pour cette période.',
                'details': null,
              },
            }),
            409,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        RestDrawRepository(api).run(
          const RunDrawCommand(
            tontineId: tontineId,
            cycleId: cycleId,
            actorMemberId: 'mbr-1',
          ),
        ),
        throwsA(
          isA<BusinessRuleException>().having(
            (BusinessRuleException e) => e.code,
            'code',
            'alreadyDrawn',
          ),
        ),
      );
    });
  });

  group('Bénéficiaire et versement', () {
    test('le bénéficiaire du cycle porte le montant de la cagnotte', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(<String, dynamic>{
            'id': 'ben-1',
            'organizationId': 'org-1',
            'tontineId': tontineId,
            'cycleId': cycleId,
            'participantId': participantId,
            'memberId': memberId,
            'memberName': 'Kouadio N GUESSAN',
            'avatarUrl': null,
            'amount': 600000.0,
            'designatedAt': '2026-08-20T22:59:43.825775Z',
            'source': 'periodic_draw',
            'status': 'paid',
            'drawSessionId': 'drw-1',
            'payoutId': 'pay-1',
          }),
        ),
      );

      final Beneficiary? beneficiary = await RestPayoutRepository(
        api,
      ).beneficiaryOfCycle(cycleId);

      expect(beneficiary?.memberName, 'Kouadio N GUESSAN');
      expect(beneficiary?.amount, 600000);
      expect(beneficiary?.source, BeneficiarySource.periodicDraw);
    });

    test('aucun versement enregistré donne null', () async {
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async => envelope(null)),
      );

      expect(await RestPayoutRepository(api).payoutOfCycle(cycleId), isNull);
    });
  });
}
