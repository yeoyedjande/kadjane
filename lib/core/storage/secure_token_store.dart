import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/domain/entities/auth_tokens.dart';

/// Stockage sécurisé des jetons de session.
abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Android : chiffrement AES-GCM adossé au KeyStore (par défaut).
            aOptions: AndroidOptions(),
            // iOS : trousseau accessible après le premier déverrouillage.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final String? raw = await _storage.read(key: StorageKeys.authTokens);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) => _storage.write(
    key: StorageKeys.authTokens,
    value: jsonEncode(tokens.toJson()),
  );

  @override
  Future<void> clear() => _storage.delete(key: StorageKeys.authTokens);
}

/// Implémentation mémoire pour les tests et les plateformes non supportées.
class InMemoryTokenStore implements TokenStore {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
