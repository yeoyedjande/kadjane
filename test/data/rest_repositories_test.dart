import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/dto/activity_dto.dart';
import 'package:kadjane/data/dto/identity_dto.dart';
import 'package:kadjane/data/dto/organization_dto.dart';
import 'package:kadjane/data/dto/tontine_dto.dart';
import 'package:kadjane/data/remote/http_api_client.dart';
import 'package:kadjane/data/repositories/rest_auth_repository.dart';
import 'package:kadjane/data/repositories/rest_contribution_repository.dart';
import 'package:kadjane/data/repositories/rest_draw_repository.dart';
import 'package:kadjane/data/repositories/rest_tontine_repository.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';

void main() {
  const String baseUrl = 'https://api.test.kadjane.app/v1';

  http.Response json(Object payload, [int status = 200]) => http.Response(
    jsonEncode(payload),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );

  HttpApiClient apiWith(MockClient mock, {InMemoryTokenStore? tokenStore}) =>
      HttpApiClient(
        tokenStore: tokenStore ?? InMemoryTokenStore(),
        httpClient: mock,
        baseUrl: baseUrl,
      );

  group('RestAuthRepository', () {
    test('stocke les jetons et l\'utilisateur après connexion', () async {
      final InMemoryTokenStore tokens = InMemoryTokenStore();
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      late String capturedPath;
      final RestAuthRepository repository = RestAuthRepository(
        apiWith(
          MockClient((http.Request request) async {
            capturedPath = request.url.path;
            return json(<String, dynamic>{
              'user': <String, dynamic>{
                'id': 'usr_1',
                'firstName': 'Yedjane',
                'lastName': 'YEO',
                'phone': '+225 07 00 00 00 01',
              },
              'tokens': <String, dynamic>{
                'accessToken': 'a',
                'refreshToken': 'r',
                'expiresAt': DateTime.now()
                    .add(const Duration(hours: 4))
                    .toIso8601String(),
              },
            });
          }),
          tokenStore: tokens,
        ),
        tokens,
        store,
      );

      final AuthSession session = await repository.signIn(
        identifier: '+225 07 00 00 00 01',
        password: 'secret',
      );

      expect(capturedPath, endsWith('/auth/login'));
      expect(session.user.fullName, 'Yedjane YEO');
      expect((await tokens.read())?.accessToken, 'a');
      expect(await store.getString(StorageKeys.currentUserId), 'usr_1');
    });

    test(
      'purge la session locale même si le serveur est injoignable',
      () async {
        final InMemoryTokenStore tokens = InMemoryTokenStore();
        final InMemoryKeyValueStore store = InMemoryKeyValueStore();
        await store.setString(StorageKeys.currentUserId, 'usr_1');
        final RestAuthRepository repository = RestAuthRepository(
          apiWith(
            MockClient(
              (http.Request request) async =>
                  json(<String, dynamic>{'message': 'ko'}, 500),
            ),
            tokenStore: tokens,
          ),
          tokens,
          store,
        );

        await repository.signOut();

        expect(await tokens.read(), isNull);
        expect(await store.getString(StorageKeys.currentUserId), isNull);
      },
    );
  });

  group('RestTontineRepository', () {
    test(
      'interroge la route de l\'organisation et mappe les synthèses',
      () async {
        late Uri captured;
        final RestTontineRepository repository = RestTontineRepository(
          apiWith(
            MockClient((http.Request request) async {
              captured = request.url;
              return json(<Object>[
                <String, dynamic>{
                  'tontine': <String, dynamic>{
                    'id': 'ton_1',
                    'organizationId': 'org_1',
                    'name': 'Tontine Solidarité',
                    'contributionAmount': 50000,
                    'currency': 'XOF',
                    'frequency': 'monthly',
                    'allocationMode': 'monthly_draw',
                    'startDate': '2026-03-01T00:00:00.000Z',
                    'status': 'active',
                    'createdBy': 'mbr_1',
                  },
                  'participantCount': 12,
                  'completedCycles': 5,
                  'totalCycles': 12,
                  'collectedCurrentCycle': 550000,
                  'expectedCurrentCycle': 600000,
                  'currentBeneficiaryName': 'Awa KOUASSI',
                },
              ]);
            }),
          ),
        );

        final List<TontineSummaryResult> summaries = <TontineSummaryResult>[
          for (final dynamic summary in await repository.list(
            organizationId: 'org_1',
            status: TontineStatus.active,
          ))
            TontineSummaryResult(summary),
        ];

        expect(captured.path, endsWith('/organizations/org_1/tontines'));
        expect(captured.queryParameters['status'], 'active');
        expect(summaries.single.name, 'Tontine Solidarité');
        expect(summaries.single.pot, 600000);
        expect(summaries.single.currency, Currency.xof);
      },
    );

    test('traite un corps vide comme « aucun cycle en cours »', () async {
      final RestTontineRepository repository = RestTontineRepository(
        apiWith(
          MockClient((http.Request request) async => http.Response('', 204)),
        ),
      );

      final TontineCycle? cycle = await repository.currentCycle('ton_1');

      expect(cycle, isNull);
    });
  });

  group('RestContributionRepository', () {
    test('poste la cotisation sur la route de la tontine', () async {
      late String path;
      late Map<String, dynamic> body;
      final RestContributionRepository repository = RestContributionRepository(
        apiWith(
          MockClient((http.Request request) async {
            path = request.url.path;
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return json(<String, dynamic>{
              'id': 'ctr_1',
              'organizationId': 'org_1',
              'tontineId': 'ton_1',
              'cycleId': 'cyc_1',
              'memberId': 'mbr_9',
              'memberName': 'Salif OUATTARA',
              'amount': 50000,
              'status': 'confirmed',
              'method': 'wave',
              'recordedAt': '2026-08-18T10:00:00.000Z',
            });
          }),
        ),
      );

      final Contribution contribution = await repository.record(
        actorMemberId: 'mbr_2',
        draft: const ContributionDraft(
          tontineId: 'ton_1',
          cycleId: 'cyc_1',
          memberId: 'mbr_9',
          amount: 50000,
          method: PaymentMethod.wave,
        ),
      );

      expect(path, endsWith('/tontines/ton_1/contributions'));
      expect(body['memberId'], 'mbr_9');
      expect(body['method'], 'wave');
      expect(body['actorMemberId'], 'mbr_2');
      expect(contribution.status, ContributionStatus.confirmed);
      expect(contribution.countsAsCollected, isTrue);
    });
  });

  group('RestDrawRepository', () {
    test(
      'transmet le forçage et mappe la session scellée par le serveur',
      () async {
        late Map<String, dynamic> body;
        final RestDrawRepository repository = RestDrawRepository(
          apiWith(
            MockClient((http.Request request) async {
              body = jsonDecode(request.body) as Map<String, dynamic>;
              return json(<String, dynamic>{
                'id': 'drw_1',
                'organizationId': 'org_1',
                'tontineId': 'ton_1',
                'cycleId': 'cyc_1',
                'periodLabel': 'Août 2026',
                'status': 'completed',
                'proofReference': 'KDJ-9F2A11B0',
                'randomSourceLabel': 'server_hmac_drbg',
                'winnerParticipantId': 'prt_3',
                'winnerName': 'YEO Yedjane',
                'overrideUsed': true,
                'overrideReason': 'Décision du bureau',
                'executedAt': '2026-08-18T14:32:00.000Z',
                'participants': <Object>[
                  <String, dynamic>{
                    'participantId': 'prt_3',
                    'memberId': 'mbr_1',
                    'displayName': 'YEO Yedjane',
                  },
                ],
              });
            }),
          ),
        );

        final DrawSession session = await repository.run(
          const RunDrawCommand(
            tontineId: 'ton_1',
            cycleId: 'cyc_1',
            actorMemberId: 'mbr_1',
            override: true,
            overrideReason: 'Décision du bureau',
          ),
        );

        expect(body['override'], isTrue);
        expect(body['overrideReason'], 'Décision du bureau');
        expect(session.status, DrawStatus.completed);
        expect(session.isCompleted, isTrue);
        expect(session.winnerName, 'YEO Yedjane');
        expect(session.randomSourceLabel, 'server_hmac_drbg');
        expect(session.participants.single.participantId, 'prt_3');
      },
    );

    test('mappe le blocage renvoyé par le serveur', () async {
      final RestDrawRepository repository = RestDrawRepository(
        apiWith(
          MockClient(
            (http.Request request) async => json(<String, dynamic>{
              'allowed': false,
              'reason': 'missingContributions',
              'missingContributions': 1,
              'canOverride': true,
            }),
          ),
        ),
      );

      final dynamic eligibility = await repository.eligibility(
        tontineId: 'ton_1',
        cycleId: 'cyc_1',
      );

      expect(eligibility.allowed, isFalse);
      expect(eligibility.missingContributions, 1);
      expect(eligibility.canOverride, isTrue);
    });
  });

  group('Mappers', () {
    test('un champ obligatoire manquant lève une erreur explicite', () {
      expect(
        () => UserDto.fromJson(<String, dynamic>{'firstName': 'Awa'}),
        throwsA(isA<ServerException>()),
      );
    });

    test('les réglages d\'organisation ont des valeurs par défaut sûres', () {
      final Organization organization = OrganizationDto.fromJson(
        <String, dynamic>{'id': 'org_1', 'name': 'Association Solidarité'},
      );

      expect(organization.currency, Currency.xof);
      expect(organization.settings.requireFullPaymentBeforeDraw, isTrue);
      expect(organization.settings.latePaymentGraceDays, 3);
    });

    test('une cotisation absente laisse la ligne « non payée »', () {
      final ContributionSlot slot = ContributionSlotDto.fromJson(
        <String, dynamic>{
          'memberId': 'mbr_9',
          'memberName': 'Salif OUATTARA',
          'expectedAmount': 50000,
        },
      );

      expect(slot.isPaid, isFalse);
      expect(slot.status, isNull);
      expect(slot.paidAmount, 0);
    });

    test('le dashboard agrégé est reconstruit intégralement', () {
      final DashboardSnapshot snapshot = DashboardSnapshotDto.fromJson(
        <String, dynamic>{
          'organization': <String, dynamic>{'id': 'org_1', 'name': 'Kadjane'},
          'membersCount': 12,
          'activeTontines': 2,
          'expectedThisPeriod': 600000,
          'collectedThisPeriod': 550000,
          'lateContributions': 1,
          'myContributionDue': 50000,
          'myContributionPaid': 50000,
          'trend': <Object>[
            <String, dynamic>{
              'periodStart': '2026-08-01T00:00:00.000Z',
              'collected': 550000,
              'expected': 600000,
            },
          ],
          'nextDraw': <String, dynamic>{
            'tontineId': 'ton_1',
            'tontineName': 'Tontine Solidarité',
            'cycleId': 'cyc_6',
            'periodStart': '2026-08-01T00:00:00.000Z',
            'scheduledAt': '2026-08-07T00:00:00.000Z',
            'eligibleCount': 7,
            'potAmount': 600000,
            'isUnlocked': false,
          },
        },
      );

      expect(snapshot.membersCount, 12);
      expect(snapshot.remainingThisPeriod, 50000);
      expect(snapshot.collectionProgress, closeTo(0.9166, 0.001));
      expect(snapshot.nextDraw?.isUnlocked, isFalse);
      expect(snapshot.currentBeneficiary, isNull);
      expect(snapshot.trend.single.collected, 550000);
    });
  });
}

/// Petit adaptateur de lecture pour éviter d'importer le type de synthèse
/// dans les assertions.
class TontineSummaryResult {
  TontineSummaryResult(this._summary);

  final dynamic _summary;

  String get name => _summary.tontine.name as String;

  double get pot => _summary.pot as double;

  Currency get currency => _summary.tontine.currency as Currency;
}
