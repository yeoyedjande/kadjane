import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/core/config/app_config.dart';

/// Verrouille le choix du backend selon l'environnement.
///
/// Sans `--dart-define=KADJANE_ENV`, l'application vise le backend **local** :
/// c'est voulu, mais c'est aussi la source de confusion la plus fréquente
/// (« l'app récupère encore les valeurs en local »). Ces tests rendent la règle
/// explicite et empêchent une URL de Beta de se glisser dans le développement,
/// ou l'inverse.
void main() {
  group('AppConfig', () {
    test('la recette et la production visent le backend de la Beta', () {
      expect(AppConfig.staging().apiBaseUrl, AppConfig.betaApiBaseUrl);
      expect(AppConfig.production().apiBaseUrl, AppConfig.betaApiBaseUrl);
    });

    test('le backend de la Beta est joignable en HTTPS', () {
      final Uri uri = Uri.parse(AppConfig.betaApiBaseUrl);

      expect(uri.scheme, 'https');
      expect(uri.path, '/api/v1');
    });

    test('le développement reste sur le backend local', () {
      expect(AppConfig.development().apiBaseUrl, contains('8000'));
      expect(AppConfig.development().apiBaseUrl, isNot(contains('railway')));
    });

    test('sans dart-define, un binaire de debug reste en développement', () {
      // Les tests tournent en mode debug, sans `--dart-define` : c'est
      // exactement la situation d'un `flutter run` nu.
      expect(AppConfig.fromDartDefine().environment, AppEnvironment.development);
    });

    test('aucun environnement distant ne vise un hôte local', () {
      // Régression : un APK compilé sans `--dart-define` visait `10.0.2.2`,
      // inexistant sur le téléphone d'un beta-testeur. La release bascule
      // désormais d'office en production — ces URL doivent donc être distantes.
      for (final AppConfig config in <AppConfig>[
        AppConfig.staging(),
        AppConfig.production(),
      ]) {
        expect(config.apiBaseUrl, isNot(contains('localhost')));
        expect(config.apiBaseUrl, isNot(contains('10.0.2.2')));
        expect(config.apiBaseUrl, startsWith('https://'));
      }
    });

    test('aucun environnement ne bascule sur les mocks par défaut', () {
      expect(AppConfig.development().useMockData, isFalse);
      expect(AppConfig.staging().useMockData, isFalse);
      expect(AppConfig.production().useMockData, isFalse);
    });
  });
}
