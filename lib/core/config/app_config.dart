/// Configuration centralisée de l'application.
///
/// Aucune URL d'API ne doit être écrite en dur dans le code : tout passe par
/// [AppConfig.current]. L'environnement est choisi au démarrage
/// (`lib/main.dart`) ou via `--dart-define=KADJANE_ENV=staging`.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;

enum AppEnvironment {
  development('development'),
  staging('staging'),
  production('production');

  const AppEnvironment(this.code);

  final String code;

  static AppEnvironment fromCode(String value) {
    return AppEnvironment.values.firstWhere(
      (AppEnvironment env) => env.code == value,
      orElse: () => AppEnvironment.development,
    );
  }
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.useMockData,
    required this.networkLatency,
    required this.enableVerboseLogs,
    this.appName = 'Kadjane',
  });

  /// Développement : backend local (`docker compose up -d`).
  ///
  /// Les mocks restent disponibles comme repli hors ligne :
  ///   flutter run --dart-define=KADJANE_USE_MOCK=true
  factory AppConfig.development() => AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: _apiBaseUrlOverride ?? defaultDevApiBaseUrl,
    useMockData: _mockOverride ?? false,
    networkLatency: const Duration(milliseconds: 350),
    enableVerboseLogs: true,
  );

  /// Recette : backend REST.
  factory AppConfig.staging() => AppConfig(
    environment: AppEnvironment.staging,
    apiBaseUrl: _apiBaseUrlOverride ?? betaApiBaseUrl,
    useMockData: _mockOverride ?? false,
    networkLatency: Duration.zero,
    enableVerboseLogs: true,
  );

  /// Production : backend REST.
  factory AppConfig.production() => AppConfig(
    environment: AppEnvironment.production,
    apiBaseUrl: _apiBaseUrlOverride ?? betaApiBaseUrl,
    useMockData: _mockOverride ?? false,
    networkLatency: Duration.zero,
    enableVerboseLogs: false,
  );

  factory AppConfig.forEnvironment(AppEnvironment environment) {
    switch (environment) {
      case AppEnvironment.development:
        return AppConfig.development();
      case AppEnvironment.staging:
        return AppConfig.staging();
      case AppEnvironment.production:
        return AppConfig.production();
    }
  }

  final AppEnvironment environment;
  final String apiBaseUrl;

  /// Vrai : les repositories mock alimentent l'application (démo hors ligne).
  /// Faux : les repositories REST appellent [apiBaseUrl].
  final bool useMockData;

  /// Latence simulée par les repositories mock.
  final Duration networkLatency;
  final bool enableVerboseLogs;
  final String appName;

  bool get isProduction => environment == AppEnvironment.production;

  /// Forçage explicite de la source de données, quel que soit l'environnement.
  ///
  ///   flutter run --dart-define=KADJANE_ENV=staging --dart-define=KADJANE_USE_MOCK=true
  static const String _mockDefine = String.fromEnvironment('KADJANE_USE_MOCK');

  static bool? get _mockOverride =>
      _mockDefine.isEmpty ? null : _mockDefine.toLowerCase() == 'true';

  /// URL du backend, surchargeable sans recompiler la configuration :
  ///
  ///   flutter run --dart-define=KADJANE_API_BASE_URL=http://192.168.1.10:8000/api/v1
  static const String _apiBaseUrlDefine = String.fromEnvironment(
    'KADJANE_API_BASE_URL',
  );

  static String? get _apiBaseUrlOverride =>
      _apiBaseUrlDefine.isEmpty ? null : _apiBaseUrlDefine;

  /// Backend de la Beta, déployé sur Railway.
  ///
  /// Recette et production le partagent tant qu'un domaine propre n'existe
  /// pas : à ce moment-là, `api.staging.kadjane.app` et `api.kadjane.app`
  /// reprendront chacun leur place.
  static const String betaApiBaseUrl =
      'https://kadjane.up.railway.app/api/v1';

  /// Backend local par défaut en développement.
  ///
  /// L'hôte dépend de la cible :
  ///  * émulateur Android : `10.0.2.2` (alias de la machine hôte) ;
  ///  * simulateur iOS, Chrome, bureau : `localhost` ;
  ///  * appareil physique : l'IP de la machine, via `KADJANE_API_BASE_URL`.
  static String get defaultDevApiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://localhost:8000/api/v1';
  }

  static AppConfig _current = AppConfig.development();

  static AppConfig get current => _current;

  static void initialize(AppConfig config) => _current = config;

  /// Résout l'environnement depuis `--dart-define=KADJANE_ENV=...`.
  ///
  /// Sans valeur explicite, le choix dépend du mode de compilation :
  ///
  ///  * **release** — `production`. Un APK distribué ne doit jamais viser
  ///    `localhost` ni `10.0.2.2` : ces hôtes n'existent pas sur le téléphone
  ///    d'un beta-testeur, et l'application échouerait sur « Impossible de
  ///    charger les données » sans autre indice.
  ///  * **debug / profile** — `development`, pour garder `flutter run` branché
  ///    sur le backend local.
  ///
  /// Le drapeau reste prioritaire : `--dart-define=KADJANE_ENV=development`
  /// permet de compiler une release pointant vers un backend local.
  static AppConfig fromDartDefine() {
    const String raw = String.fromEnvironment('KADJANE_ENV');
    if (raw.isNotEmpty) {
      return AppConfig.forEnvironment(AppEnvironment.fromCode(raw));
    }
    return AppConfig.forEnvironment(
      kReleaseMode ? AppEnvironment.production : AppEnvironment.development,
    );
  }
}
