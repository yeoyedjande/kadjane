import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/core/utils/logger.dart';
import 'package:kadjane/domain/entities/auth_tokens.dart';

/// Client HTTP du backend Kadjane.
///
/// Responsabilités :
///  * préfixer les appels par l'URL de l'environnement courant ;
///  * injecter le jeton d'accès (`Authorization: Bearer …`) ;
///  * renouveler automatiquement une session expirée (une seule fois) puis
///    rejouer la requête ;
///  * convertir les erreurs de transport et les codes HTTP en
///    [AppException] typées, jamais exposées telles quelles à l'utilisateur.
class HttpApiClient implements ApiClient {
  HttpApiClient({
    required TokenStore tokenStore,
    http.Client? httpClient,
    String? baseUrl,
    Duration? timeout,
  }) : _tokens = tokenStore,
       _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.current.apiBaseUrl,
       _timeout = timeout ?? const Duration(seconds: 20);

  final TokenStore _tokens;
  final http.Client _http;
  final String _baseUrl;
  final Duration _timeout;

  static const AppLogger _logger = AppLogger('api');

  /// Évite plusieurs rafraîchissements simultanés (requêtes parallèles en 401).
  Future<AuthTokens?>? _refreshing;

  @override
  Future<JsonMap> get(String path, {Map<String, dynamic>? query}) async =>
      _asMap(await _send('GET', path, query: query), path);

  @override
  Future<List<JsonMap>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final Object? payload = _unwrap(await _send('GET', path, query: query));
    // Certains backends encapsulent les collections dans `{ "data": [...] }`.
    final Object? list = payload is Map<String, dynamic>
        ? payload['data'] ?? payload['items']
        : payload;
    if (list is! List<dynamic>) {
      throw ServerException('invalid_list_payload:$path');
    }
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  @override
  Future<JsonMap> post(String path, {Object? body}) async =>
      _asMap(await _send('POST', path, body: body), path);

  @override
  Future<JsonMap> put(String path, {Object? body}) async =>
      _asMap(await _send('PUT', path, body: body), path);

  @override
  Future<JsonMap> patch(String path, {Object? body}) async =>
      _asMap(await _send('PATCH', path, body: body), path);

  @override
  Future<void> delete(String path) async => _send('DELETE', path);

  void close() => _http.close();

  // --- Interne -------------------------------------------------------------

  /// Routes publiques d'authentification (connexion, inscription, OTP…).
  static bool _isAuthRoute(String path) => path.startsWith('/auth/');

  JsonMap _asMap(Object? payload, String path) {
    final Object? content = _unwrap(payload);
    if (content == null) {
      return <String, dynamic>{};
    }
    if (content is Map<String, dynamic>) {
      return content;
    }
    throw ServerException('invalid_object_payload:$path');
  }

  /// Déballe l'enveloppe du backend : `{ "success": true, "data": …, "meta": … }`.
  ///
  /// Les réponses nues restent acceptées — le contrat d'API autorise les deux
  /// formes, et les mappers n'ont donc rien à savoir de l'enveloppe.
  static Object? _unwrap(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      return payload;
    }
    final bool isEnvelope =
        payload.containsKey('success') ||
        (payload.length == 1 && payload.containsKey('data'));
    if (!isEnvelope || !payload.containsKey('data')) {
      return payload;
    }
    return payload['data'];
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool allowRetry = true,
  }) async {
    final Uri uri = _resolve(path, query);
    final String? token = (await _tokens.read())?.accessToken;

    http.Response response;
    try {
      response = await _dispatch(method, uri, token, body).timeout(_timeout);
    } on TimeoutException catch (error) {
      throw NetworkException('timeout:$path', error);
    } on Object catch (error) {
      // Socket, DNS, TLS… : indiscernables du point de vue de l'appelant.
      throw NetworkException('transport_error:$path', error);
    }

    // Un 401 sur `/auth/*` n'est pas une session expirée mais un refus
    // d'identifiants : ni renouvellement, ni purge de session.
    if (response.statusCode == 401 && allowRetry && !_isAuthRoute(path)) {
      final AuthTokens? renewed = await _refreshSession();
      if (renewed != null) {
        return _send(method, path, query: query, body: body, allowRetry: false);
      }
      await _tokens.clear();
      throw const SessionExpiredException();
    }

    return _decode(response, path);
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    String? token,
    Object? body,
  ) {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final String? payload = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: payload);
      case 'PUT':
        return _http.put(uri, headers: headers, body: payload);
      case 'PATCH':
        return _http.patch(uri, headers: headers, body: payload);
      case 'DELETE':
        return _http.delete(uri, headers: headers, body: payload);
      default:
        throw UnexpectedException('unsupported_method:$method');
    }
  }

  Uri _resolve(String path, Map<String, dynamic>? query) {
    final Uri base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) {
      return base;
    }
    final Map<String, String> parameters = <String, String>{};
    query.forEach((String key, dynamic value) {
      if (value == null) {
        return;
      }
      parameters[key] = value is Iterable<Object?>
          ? value.map((Object? v) => '$v').join(',')
          : '$value';
    });
    return base.replace(
      queryParameters: <String, String>{...base.queryParameters, ...parameters},
    );
  }

  Object? _decode(http.Response response, String path) {
    final int status = response.statusCode;
    final String raw = utf8.decode(response.bodyBytes, allowMalformed: true);
    final Object? payload = raw.trim().isEmpty ? null : _tryDecode(raw);

    if (status >= 200 && status < 300) {
      return payload;
    }

    final String message = _extractMessage(payload) ?? 'http_$status';
    _logger.warn('$path -> $status');

    switch (status) {
      case 400:
      case 422:
        throw ValidationException(message, fieldErrors: _fieldErrors(payload));
      case 401:
        if (_isAuthRoute(path)) {
          throw AuthException(
            message,
            code: _extractCode(payload) ?? 'invalid_credentials',
          );
        }
        throw const SessionExpiredException();
      case 403:
        throw PermissionDeniedException(message);
      case 404:
        throw NotFoundException(message);
      case 409:
        throw BusinessRuleException(
          message,
          code: _extractCode(payload),
          details: payload is Map<String, dynamic> ? payload : null,
        );
      default:
        if (status >= 500) {
          throw ServerException(message, status);
        }
        throw ServerException(message, status);
    }
  }

  Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// Corps d'erreur : `{ "error": { code, message, details } }` ou champs à plat.
  JsonMap? _errorBody(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final Object? nested = payload['error'];
    return nested is Map<String, dynamic> ? nested : payload;
  }

  String? _extractMessage(Object? payload) {
    final JsonMap? body = _errorBody(payload);
    final Object? message = body?['message'] ?? body?['error'];
    return message is String && message.isNotEmpty ? message : null;
  }

  String? _extractCode(Object? payload) {
    final Object? code = _errorBody(payload)?['code'];
    return code is String && code.isNotEmpty ? code : null;
  }

  Map<String, String>? _fieldErrors(Object? payload) {
    final JsonMap? body = _errorBody(payload);
    if (body == null) {
      return null;
    }
    final Object? details = body['details'];
    final Object? errors =
        body['errors'] ??
        (details is Map<String, dynamic> ? details['errors'] : null);
    if (errors is Map<String, dynamic>) {
      return errors.map(
        (String key, dynamic value) => MapEntry<String, String>(key, '$value'),
      );
    }
    return null;
  }

  /// Renouvelle la session via `/auth/refresh`, sans jeton d'accès.
  Future<AuthTokens?> _refreshSession() {
    return _refreshing ??= _performRefresh().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<AuthTokens?> _performRefresh() async {
    final AuthTokens? current = await _tokens.read();
    if (current == null) {
      return null;
    }
    try {
      final http.Response response = await _http
          .post(
            _resolve(ApiRoutes.refresh, null),
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(<String, String>{
              'refreshToken': current.refreshToken,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final Object? payload = _unwrap(
        _tryDecode(utf8.decode(response.bodyBytes, allowMalformed: true)),
      );
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final Map<String, dynamic> tokenJson =
          payload['tokens'] as Map<String, dynamic>? ?? payload;
      final AuthTokens renewed = AuthTokens.fromJson(tokenJson);
      await _tokens.write(renewed);
      _logger.info('session renouvelée');
      return renewed;
    } on Object catch (error, stackTrace) {
      _logger.error('échec du renouvellement de session', error, stackTrace);
      return null;
    }
  }
}
