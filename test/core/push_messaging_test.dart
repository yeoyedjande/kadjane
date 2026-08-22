import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/core/services/push_messaging.dart';

/// Les notifications push ne doivent jamais faire tomber l'application.
///
/// Régression : `FirebaseMessaging.instance` était résolu dans le constructeur,
/// donc avant toute protection. Sans greffon natif — en test, sur un appareil
/// sans services Google, ou si `google-services.json` manque au build — une
/// `FirebaseException` remontait jusqu'à l'écran.
void main() {
  test('l\'initialisation échoue en douceur sans Firebase', () async {
    // Aucun greffon natif dans l'environnement de test : c'est précisément le
    // cas que le service doit absorber.
    expect(await PushMessaging().initialize(), isFalse);
  });

  test('la permission est simplement refusée, sans exception', () async {
    expect(await PushMessaging().requestPermission(), isFalse);
  });

  test('le jeton vaut null plutôt que de lever', () async {
    expect(await PushMessaging().token(), isNull);
  });

  test('les flux sont vides tant que Firebase n\'est pas prêt', () async {
    final PushMessaging push = PushMessaging();

    expect(await push.onTokenRefresh.isEmpty, isTrue);
    expect(await push.onMessage.isEmpty, isTrue);
    expect(await push.onMessageOpenedApp.isEmpty, isTrue);
  });
}
