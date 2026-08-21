import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/dto/identity_dto.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/auth_tokens.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/repositories/auth_repository.dart';

/// Authentification adossée au backend REST.
///
/// Les jetons sont écrits dans le stockage sécurisé ; le renouvellement
/// automatique est assuré par [HttpApiClient] lors des appels protégés.
class RestAuthRepository implements AuthRepository {
  RestAuthRepository(this._api, this._tokens, this._store);

  final ApiClient _api;
  final TokenStore _tokens;
  final KeyValueStore _store;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    final JsonMap response = await _api.post(
      ApiRoutes.login,
      body: <String, dynamic>{'identifier': identifier, 'password': password},
    );
    return _persist(AuthSessionDto.fromJson(response));
  }

  @override
  Future<AuthSession> register(RegisterDraft draft) async {
    final JsonMap response = await _api.post(
      ApiRoutes.register,
      body: RegisterDraftDto.toJson(draft),
    );
    return _persist(AuthSessionDto.fromJson(response));
  }

  @override
  Future<void> requestOtp(String target) async {
    await _api.post(
      ApiRoutes.requestOtp,
      body: <String, dynamic>{'target': target},
    );
  }

  @override
  Future<String> verifyOtp({
    required String target,
    required String code,
  }) async {
    final JsonMap response = await _api.post(
      ApiRoutes.verifyOtp,
      body: <String, dynamic>{'target': target, 'code': code},
    );
    return Json.string(response, 'resetToken');
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _api.post(
      ApiRoutes.resetPassword,
      body: <String, dynamic>{
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      ApiRoutes.changePassword,
      body: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final AuthTokens? tokens = await _tokens.read();
    if (tokens == null) {
      return null;
    }
    if (tokens.isExpired) {
      // Le client tentera un renouvellement ; en cas d'échec la session tombe.
      try {
        return await refreshSession();
      } on AppException {
        await signOut();
        return null;
      }
    }
    try {
      final User user = UserDto.fromJson(await _api.get(ApiRoutes.me));
      await _store.setString(StorageKeys.currentUserId, user.id);
      return AuthSession(user: user, tokens: tokens);
    } on SessionExpiredException {
      await signOut();
      return null;
    }
  }

  @override
  Future<AuthSession> refreshSession() async {
    final AuthTokens? current = await _tokens.read();
    if (current == null) {
      throw const SessionExpiredException();
    }
    final JsonMap response = await _api.post(
      ApiRoutes.refresh,
      body: <String, dynamic>{'refreshToken': current.refreshToken},
    );
    final AuthTokens tokens = AuthTokensDto.fromJson(
      Json.objectOrNull(response, 'tokens') ?? response,
    );
    await _tokens.write(tokens);
    final User user = UserDto.fromJson(await _api.get(ApiRoutes.me));
    return _persist(AuthSession(user: user, tokens: tokens));
  }

  @override
  Future<void> signOut() async {
    try {
      await _api.post(ApiRoutes.logout);
    } on AppException {
      // La session locale doit être purgée même si le serveur est injoignable.
    }
    await _tokens.clear();
    await _store.remove(StorageKeys.currentUserId);
    await _store.remove(StorageKeys.activeOrganization);
  }

  @override
  Future<User> updateProfile(User user) async => UserDto.fromJson(
    await _api.put(ApiRoutes.me, body: UserDto.toJson(user)),
  );

  Future<AuthSession> _persist(AuthSession session) async {
    await _tokens.write(session.tokens);
    await _store.setString(StorageKeys.currentUserId, session.user.id);
    return session;
  }
}
