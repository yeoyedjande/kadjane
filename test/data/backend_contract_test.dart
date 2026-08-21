import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/remote/http_api_client.dart';
import 'package:kadjane/data/repositories/rest_auth_repository.dart';
import 'package:kadjane/data/repositories/rest_member_repository.dart';
import 'package:kadjane/data/repositories/rest_organization_repository.dart';
import 'package:kadjane/data/repositories/rest_support_repositories.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/auth_tokens.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';

/// Vérifie que les repositories REST consomment les réponses **réelles** du
/// backend FastAPI (`backend/`), enveloppe `{success, data, meta}` comprise.
///
/// Les charges utiles ci-dessous sont copiées telles quelles depuis
/// `GET/POST http://localhost:8000/api/v1/...` sur la base seedée.
void main() {
  const String baseUrl = 'http://localhost:8000/api/v1';
  const String orgId = '137b04e7-3c3e-452f-9508-da59e2452830';
  const String userId = 'f72c2bf9-1635-435e-a496-0b9a54917bba';
  const String memberId = 'e1aaa90d-bbd3-42c8-a07a-75275a387a13';

  final Map<String, dynamic> userPayload = <String, dynamic>{
    'id': userId,
    'firstName': 'Yedjane',
    'lastName': 'YEO',
    'phone': '+225 07 00 00 00 01',
    'email': 'yeo@kadjane.app',
    'avatarUrl': null,
    'gender': 'male',
    'birthDate': null,
    'createdAt': '2026-08-20T22:03:09.020244Z',
  };

  final Map<String, dynamic> organizationPayload = <String, dynamic>{
    'id': orgId,
    'name': 'Association Solidarité',
    'slug': 'association-solidarite',
    'description': 'Association de solidarité familiale et professionnelle.',
    'logoUrl': null,
    'currency': 'XOF',
    'country': 'CI',
    'phone': '+225 27 22 00 00 00',
    'email': 'contact@solidarite.ci',
    'address': 'Cocody Angré, Abidjan',
    'rules': 'Les cotisations sont dues le 5 de chaque mois.',
    'settings': <String, dynamic>{
      'requireFullPaymentBeforeDraw': true,
      'allowDrawOverride': true,
      'latePaymentGraceDays': 3,
      'notifyBeforeDueDays': 3,
    },
    'status': 'active',
    'createdBy': userId,
    'createdAt': '2026-08-20T22:03:09.020244Z',
  };

  Map<String, dynamic> memberPayload(
    String id,
    String firstName,
    String lastName,
    String role,
    String number,
  ) => <String, dynamic>{
    'id': id,
    'organizationId': orgId,
    'user': <String, dynamic>{
      ...userPayload,
      'firstName': firstName,
      'lastName': lastName,
    },
    'role': role,
    'status': 'active',
    'joinedAt': '2026-08-20T22:03:09.020244Z',
    'memberNumber': number,
  };

  http.Response ok(Object payload) => http.Response(
    jsonEncode(payload),
    200,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );

  http.Response envelope(Object data, {Map<String, dynamic>? meta}) => ok(
    <String, dynamic>{'success': true, 'data': data, 'meta': ?meta},
  );

  late InMemoryTokenStore tokens;
  late InMemoryKeyValueStore store;

  setUp(() {
    tokens = InMemoryTokenStore();
    store = InMemoryKeyValueStore();
  });

  HttpApiClient apiWith(MockClient mock) =>
      HttpApiClient(tokenStore: tokens, httpClient: mock, baseUrl: baseUrl);

  group('Connexion', () {
    test('POST /auth/login ouvre la session et enregistre les jetons', () async {
      late http.Request captured;
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async {
          captured = request;
          return envelope(<String, dynamic>{
            'user': userPayload,
            'tokens': <String, dynamic>{
              'accessToken': 'access-1',
              'refreshToken': 'refresh-1',
              'expiresAt': '2026-08-20T22:33:09.000Z',
              'tokenType': 'bearer',
            },
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
            'token_type': 'bearer',
          });
        }),
      );

      final AuthSession session = await RestAuthRepository(
        api,
        tokens,
        store,
      ).signIn(identifier: 'yeo@kadjane.app', password: 'kadjane');

      expect(captured.url.toString(), '$baseUrl/auth/login');
      expect(
        jsonDecode(captured.body),
        <String, dynamic>{'identifier': 'yeo@kadjane.app', 'password': 'kadjane'},
      );
      expect(session.user.firstName, 'Yedjane');
      expect(session.user.id, userId);

      final AuthTokens? stored = await tokens.read();
      expect(stored?.accessToken, 'access-1');
      expect(await store.getString(StorageKeys.currentUserId), userId);
    });

    test('un mot de passe refusé remonte « identifiants invalides »', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => http.Response(
            jsonEncode(<String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'invalid_credentials',
                'message': 'Identifiants invalides.',
                'details': null,
              },
            }),
            401,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        RestAuthRepository(
          api,
          tokens,
          store,
        ).signIn(identifier: 'yeo@kadjane.app', password: 'faux'),
        throwsA(
          isA<AuthException>()
              .having((AuthException e) => e.code, 'code', 'invalid_credentials')
              // Surtout pas une session expirée : le message affiché diffère.
              .having((AuthException e) => e is SessionExpiredException, 'expired', false),
        ),
      );
    });

    test('GET /me restaure la session enregistrée', () async {
      await tokens.write(
        AuthTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async {
          expect(request.url.path, '/api/v1/me');
          expect(request.headers['Authorization'], 'Bearer access-1');
          return envelope(userPayload);
        }),
      );

      final AuthSession? session = await RestAuthRepository(
        api,
        tokens,
        store,
      ).restoreSession();

      expect(session?.user.phone, '+225 07 00 00 00 01');
    });
  });

  group('Organisation active', () {
    test('GET /organizations ne renvoie que mes organisations', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(
            <Map<String, dynamic>>[organizationPayload],
            meta: <String, dynamic>{'total': 1},
          ),
        ),
      );

      final List<Organization> organizations =
          await RestOrganizationRepository(api).organizationsOf(userId);

      expect(organizations, hasLength(1));
      expect(organizations.single.name, 'Association Solidarité');
      expect(organizations.single.currency.code, 'XOF');
      expect(organizations.single.settings.latePaymentGraceDays, 3);
    });

    test('GET /organizations/{id}/membership donne le rôle courant', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(
            memberPayload(memberId, 'Yedjane', 'YEO', 'admin', 'M-001'),
          ),
        ),
      );

      final OrganizationMember membership = await RestOrganizationRepository(api)
          .membershipOf(organizationId: orgId, userId: userId);

      expect(membership.role, OrgRole.admin);
      expect(membership.status, MemberStatus.active);
      expect(membership.memberNumber, 'M-001');
    });
  });

  group('Membres', () {
    test('GET /organizations/{id}/members alimente la liste paginée', () async {
      late Uri captured;
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async {
          captured = request.url;
          return envelope(
            <String, dynamic>{
              'items': <Map<String, dynamic>>[
                memberPayload(memberId, 'Yedjane', 'YEO', 'admin', 'M-001'),
                memberPayload('b9f74465', 'Awa', 'KOUASSI', 'treasurer', 'M-002'),
              ],
              'page': 0,
              'pageSize': 2,
              'hasMore': true,
              'total': 12,
            },
            meta: <String, dynamic>{'page': 0, 'page_size': 2, 'total': 12},
          );
        }),
      );

      final PagedResult<OrganizationMember> page = await RestMemberRepository(
        api,
      ).list(organizationId: orgId, pageSize: 2);

      expect(captured.path, '/api/v1/organizations/$orgId/members');
      expect(captured.queryParameters['pageSize'], '2');
      expect(page.total, 12);
      expect(page.hasMore, isTrue);
      expect(
        page.items.map((OrganizationMember m) => m.user.lastName),
        <String>['YEO', 'KOUASSI'],
      );
      expect(page.items.first.role, OrgRole.admin);
    });

    test('la recherche est transmise au backend', () async {
      late Uri captured;
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async {
          captured = request.url;
          return envelope(<String, dynamic>{
            'items': <Map<String, dynamic>>[],
            'page': 0,
            'hasMore': false,
            'total': 0,
          });
        }),
      );

      await RestMemberRepository(api).list(organizationId: orgId, query: 'awa');

      expect(captured.queryParameters['query'], 'awa');
    });
  });

  group('Tableau de bord', () {
    test('le nombre de membres vient de la base', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => envelope(<String, dynamic>{
            'organization': organizationPayload,
            'membersCount': 12,
            'activeTontines': 0,
            'expectedThisPeriod': 0,
            'collectedThisPeriod': 0,
            'lateContributions': 0,
            'myContributionDue': 0,
            'myContributionPaid': 0,
            'deadlines': <dynamic>[],
            'recentActivity': <dynamic>[],
            'trend': <dynamic>[],
            'nextDraw': null,
            'currentBeneficiary': null,
            'members_count': 12,
            'collection_rate': 0,
          }),
        ),
      );

      final DashboardSnapshot snapshot = await RestDashboardRepository(
        api,
      ).load(organizationId: orgId, memberId: memberId);

      expect(snapshot.membersCount, 12);
      expect(snapshot.organization.name, 'Association Solidarité');
      // Non encore migré : zéro assumé, pas une valeur simulée.
      expect(snapshot.activeTontines, 0);
      expect(snapshot.nextDraw, isNull);
    });
  });

  group('Erreurs', () {
    test('un 403 devient une permission refusée lisible', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => http.Response(
            jsonEncode(<String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'permission_denied',
                'message': 'Votre rôle ne permet pas cette action.',
                'details': <String, dynamic>{'requiredPermission': 'member.create'},
              },
            }),
            403,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        api.get(ApiRoutes.members(orgId)),
        throwsA(
          isA<PermissionDeniedException>().having(
            (PermissionDeniedException e) => e.message,
            'message',
            'Votre rôle ne permet pas cette action.',
          ),
        ),
      );
    });

    test('un 422 expose les erreurs par champ', () async {
      final HttpApiClient api = apiWith(
        MockClient(
          (http.Request request) async => http.Response(
            jsonEncode(<String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'validation_error',
                'message': 'Certaines données envoyées sont invalides.',
                'details': <String, dynamic>{
                  'errors': <String, dynamic>{'phone': 'String should have at least 4 characters'},
                },
              },
            }),
            422,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        api.post(ApiRoutes.members(orgId), body: <String, dynamic>{'phone': 'x'}),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException e) => e.fieldErrors?['phone'],
            'phone',
            isNotNull,
          ),
        ),
      );
    });

    test('une panne réseau reste une NetworkException', () async {
      final HttpApiClient api = apiWith(
        MockClient((http.Request request) async => throw const SocketFailure()),
      );

      await expectLater(
        api.get(ApiRoutes.organizations),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}

/// Panne de transport simulée (socket, DNS, TLS...).
class SocketFailure implements Exception {
  const SocketFailure();
}
