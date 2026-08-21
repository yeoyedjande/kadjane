import 'dart:developer' as developer;

import 'package:kadjane/core/config/app_config.dart';

/// Journalisation centralisée.
///
/// Règle de sécurité : aucune donnée sensible (token, mot de passe, code OTP,
/// numéro complet) ne doit être passée au logger. Utiliser [redact] au besoin.
class AppLogger {
  const AppLogger(this.name);

  final String name;

  static const List<String> _sensitiveKeys = <String>[
    'password',
    'token',
    'accessToken',
    'refreshToken',
    'otp',
    'pin',
    'secret',
  ];

  void debug(String message) {
    if (!AppConfig.current.enableVerboseLogs) {
      return;
    }
    developer.log(message, name: name, level: 500);
  }

  void info(String message) {
    developer.log(message, name: name, level: 800);
  }

  void warn(String message) {
    developer.log(message, name: name, level: 900);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Masque les valeurs sensibles d'une map avant journalisation.
  static Map<String, Object?> redact(Map<String, Object?> data) {
    return data.map((String key, Object? value) {
      final bool sensitive = _sensitiveKeys.any(
        (String k) => key.toLowerCase().contains(k.toLowerCase()),
      );
      return MapEntry<String, Object?>(key, sensitive ? '***' : value);
    });
  }
}
