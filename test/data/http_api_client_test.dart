import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/remote/http_api_client.dart';
import 'package:kadjane/domain/entities/auth_tokens.dart';

void main() {
  const String baseUrl = 'https://api.test.kadjane.app/v1';

  late InMemoryTokenStore tokens;

  setUp(() async {
    tokens = InMemoryTokenStore();
    await tokens.write(
      AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
  });

  HttpApiClient clientWith(MockClient mock) =>
      HttpApiClient(tokenStore: tokens, httpClient: mock, baseUrl: baseUrl);

  http.Response json(Object payload, [int status = 200]) => http.Response(
    jsonEncode(payload),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );

  group('Requêtes', () {
    test('préfixe l\'URL et injecte le jeton d\'accès', () async {
      late http.Request captured;
      final HttpApiClient api = clientWith(
        MockClient((http.Request request) async {
          captured = request;
          return json(<String, dynamic>{'id': 'usr_1'});
        }),
      );

      final JsonMap response = await api.get(ApiRoutes.me);

      expect(captured.url.toString(), '$baseUrl/me');
      expect(captured.headers['Authorization'], 'Bearer access-1');
      expect(response['id'], 'usr_1');
    });

    test('sérialise les paramètres de requête', () async {
      late Uri captured;
      final HttpApiClient api = clientWith(
        MockClient((http.Request request) async {
          captured = request.url;
          return json(<String, dynamic>{'items': <dynamic>[]});
        }),
      );

      await api.get(
        ApiRoutes.members('org_1'),
        query: <String, dynamic>{
          'query': 'awa',
          'page': 2,
          'actions': <String>['draw.completed', 'draw.overridden'],
          'ignored': null,
        },
      );

      expect(captured.queryParameters['query'], 'awa');
      expect(captured.queryParameters['page'], '2');
      expect(
        captured.queryParameters['actions'],
        'draw.completed,draw.overridden',
      );
      expect(captured.queryParameters.containsKey('ignored'), isFalse);
    });

    test('envoie un corps JSON sur les écritures', () async {
      late String captured;
      final HttpApiClient api = clientWith(
        MockClient((http.Request request) async {
          captured = request.body;
          return json(<String, dynamic>{'id': 'ctr_1'});
        }),
      );

      await api.post(
        ApiRoutes.tontineContributions('ton_1'),
        body: <String, dynamic>{'amount': 50000},
      );

      expect(jsonDecode(captured), <String, dynamic>{'amount': 50000});
    });

    test('déballe les réponses encapsulées dans « data »', () async {
      final HttpApiClient api = clientWith(
        MockClient(
          (http.Request request) async => json(<String, dynamic>{
            'data': <String, dynamic>{'id': 'org_1'},
          }),
        ),
      );

      expect((await api.get(ApiRoutes.organization('org_1')))['id'], 'org_1');
    });

    test('accepte un tableau brut ou encapsulé pour les listes', () async {
      final HttpApiClient raw = clientWith(
        MockClient(
          (http.Request request) async => json(<Object>[
            <String, dynamic>{'id': 'a'},
          ]),
        ),
      );
      final HttpApiClient wrapped = clientWith(
        MockClient(
          (http.Request request) async => json(<String, dynamic>{
            'data': <Object>[
              <String, dynamic>{'id': 'b'},
            ],
          }),
        ),
      );

      expect((await raw.getList(ApiRoutes.organizations)).single['id'], 'a');
      expect(
        (await wrapped.getList(ApiRoutes.organizations)).single['id'],
        'b',
      );
    });
  });

  group('Conversion des erreurs', () {
    Future<void> expectError(
      int status,
      Object payload,
      Matcher matcher,
    ) async {
      final HttpApiClient api = clientWith(
        MockClient((http.Request request) async => json(payload, status)),
      );
      await expectLater(api.get(ApiRoutes.me), throwsA(matcher));
    }

    test('404 devient NotFoundException', () async {
      await expectError(404, <String, dynamic>{
        'message': 'tontine introuvable',
      }, isA<NotFoundException>());
    });

    test('403 devient PermissionDeniedException', () async {
      await expectError(403, <String, dynamic>{
        'message': 'interdit',
      }, isA<PermissionDeniedException>());
    });

    test('409 devient BusinessRuleException avec son code', () async {
      final HttpApiClient api = clientWith(
        MockClient(
          (http.Request request) async => json(<String, dynamic>{
            'code': 'missingContributions',
            'message': 'cotisations manquantes',
            'missing': 1,
          }, 409),
        ),
      );

      await expectLater(
        api.post(ApiRoutes.draws('ton_1')),
        throwsA(
          isA<BusinessRuleException>().having(
            (BusinessRuleException e) => e.code,
            'code',
            'missingContributions',
          ),
        ),
      );
    });

    test('422 devient ValidationException avec les champs en erreur', () async {
      final HttpApiClient api = clientWith(
        MockClient(
          (http.Request request) async => json(<String, dynamic>{
            'message': 'invalide',
            'errors': <String, dynamic>{'phone': 'format incorrect'},
          }, 422),
        ),
      );

      await expectLater(
        api.post(ApiRoutes.register),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException e) => e.fieldErrors?['phone'],
            'fieldErrors',
            'format incorrect',
          ),
        ),
      );
    });

    test('500 devient ServerException', () async {
      await expectError(500, <String, dynamic>{}, isA<ServerException>());
    });

    test('une panne de transport devient NetworkException', () async {
      final HttpApiClient api = clientWith(
        MockClient(
          (http.Request request) async =>
              throw const SocketExceptionStub('offline'),
        ),
      );

      await expectLater(
        api.get(ApiRoutes.me),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('Renouvellement de session', () {
    test('rejoue la requête après un 401 et un refresh réussi', () async {
      int calls = 0;
      final HttpApiClient api = clientWith(
        MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return json(<String, dynamic>{
              'accessToken': 'access-2',
              'refreshToken': 'refresh-2',
              'expiresAt': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            });
          }
          calls++;
          if (calls == 1) {
            return json(<String, dynamic>{'message': 'expiré'}, 401);
          }
          return json(<String, dynamic>{
            'id': 'usr_1',
            'token': request.headers['Authorization'],
          });
        }),
      );

      final JsonMap response = await api.get(ApiRoutes.me);

      expect(calls, 2);
      expect(response['token'], 'Bearer access-2');
      expect((await tokens.read())?.accessToken, 'access-2');
    });

    test('purge la session si le refresh échoue', () async {
      final HttpApiClient api = clientWith(
        MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return json(<String, dynamic>{'message': 'invalide'}, 401);
          }
          return json(<String, dynamic>{'message': 'expiré'}, 401);
        }),
      );

      await expectLater(
        api.get(ApiRoutes.me),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(await tokens.read(), isNull);
    });
  });
}

/// Simule une coupure réseau sans dépendre de `dart:io` (compatible web).
class SocketExceptionStub implements Exception {
  const SocketExceptionStub(this.message);

  final String message;
}
