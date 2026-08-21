import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/data/mock/mock_seed.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/auth_tokens.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/repositories/auth_repository.dart';

/// Authentification simulée.
///
/// Comptes de démonstration : n'importe quel téléphone/email présent dans le
/// jeu de données avec le mot de passe `kadjane` (code OTP `123456`).
///
/// TODO(api): remplacer par `RestAuthRepository` (POST /auth/login,
/// /auth/refresh, /auth/otp/*) — le contrat public reste identique.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._db, this._tokens, this._store);

  final MockDatabase _db;
  final TokenStore _tokens;
  final KeyValueStore _store;

  static const Duration _sessionDuration = Duration(hours: 8);

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) => _db
      .withLatency(() {
        final User? user = _db.userByIdentifier(identifier);
        if (user == null || _db.passwords[user.id] != password) {
          throw const AuthException('invalid_credentials');
        }
        return _openSession(user);
      })
      .then((AuthSession session) async {
        await _persist(session);
        return session;
      });

  @override
  Future<AuthSession> register(RegisterDraft draft) => _db
      .withLatency(() {
        if (_db.userByIdentifier(draft.phone) != null) {
          throw const ValidationException('phone_already_used');
        }
        final User user = User(
          id: _db.nextId('usr'),
          firstName: draft.firstName,
          lastName: draft.lastName,
          phone: draft.phone,
          email: draft.email,
          gender: draft.gender,
          createdAt: DateTime.now(),
        );
        _db.users.add(user);
        _db.passwords[user.id] = draft.password;
        return _openSession(user);
      })
      .then((AuthSession session) async {
        await _persist(session);
        return session;
      });

  @override
  Future<void> requestOtp(String target) => _db.withLatency(() {
    if (target.trim().isEmpty) {
      throw const ValidationException('target_required');
    }
    // Le code n'est jamais journalisé : en démo, il vaut MockSeed.demoOtp.
  });

  @override
  Future<String> verifyOtp({required String target, required String code}) =>
      _db.withLatency(() {
        if (code.trim() != MockSeed.demoOtp) {
          throw const AuthException('invalid_otp', code: 'invalid_otp');
        }
        return 'reset_${DateTime.now().millisecondsSinceEpoch}';
      });

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) => _db.withLatency(() {
    if (!resetToken.startsWith('reset_')) {
      throw const AuthException('invalid_reset_token');
    }
    if (newPassword.length < 8) {
      throw const ValidationException('password_too_short');
    }
  });

  @override
  Future<AuthSession?> restoreSession() async {
    final AuthTokens? tokens = await _tokens.read();
    final String? userId = await _store.getString(StorageKeys.currentUserId);
    if (tokens == null || userId == null) {
      return null;
    }
    if (tokens.isExpired) {
      await signOut();
      return null;
    }
    final User user = _db.userById(userId);
    if (tokens.needsRefresh) {
      final AuthSession refreshed = AuthSession(
        user: user,
        tokens: _issueTokens(),
      );
      await _persist(refreshed);
      return refreshed;
    }
    return AuthSession(user: user, tokens: tokens);
  }

  @override
  Future<AuthSession> refreshSession() async {
    final AuthTokens? tokens = await _tokens.read();
    final String? userId = await _store.getString(StorageKeys.currentUserId);
    if (tokens == null || userId == null) {
      throw const SessionExpiredException();
    }
    final AuthSession session = AuthSession(
      user: _db.userById(userId),
      tokens: _issueTokens(),
    );
    await _persist(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await _tokens.clear();
    await _store.remove(StorageKeys.currentUserId);
    await _store.remove(StorageKeys.activeOrganization);
  }

  @override
  Future<User> updateProfile(User user) => _db.withLatency(() {
    final int index = _db.users.indexWhere((User u) => u.id == user.id);
    if (index == -1) {
      throw NotFoundException('user:${user.id}');
    }
    _db.users[index] = user;
    // Le membre porte une copie de l'utilisateur dans chaque organisation.
    for (int i = 0; i < _db.members.length; i++) {
      if (_db.members[i].userId == user.id) {
        _db.members[i] = _db.members[i].copyWith(user: user);
      }
    }
    return user;
  });

  AuthSession _openSession(User user) =>
      AuthSession(user: user, tokens: _issueTokens());

  AuthTokens _issueTokens() => AuthTokens(
    accessToken: 'mock_access_${DateTime.now().microsecondsSinceEpoch}',
    refreshToken: 'mock_refresh_${DateTime.now().microsecondsSinceEpoch}',
    expiresAt: DateTime.now().add(_sessionDuration),
  );

  Future<void> _persist(AuthSession session) async {
    await _tokens.write(session.tokens);
    await _store.setString(StorageKeys.currentUserId, session.user.id);
  }
}
