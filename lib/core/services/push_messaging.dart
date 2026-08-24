import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:kadjane/core/utils/logger.dart';

/// Reçoit un message alors que l'application est fermée.
///
/// Doit être une fonction de premier niveau : Android réveille l'isolat dans
/// un contexte vierge, sans accès à l'état de l'application. Le système
/// affiche lui-même la notification ; on se contente de la journaliser.
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  const AppLogger(
    'push',
  ).info('Message reçu en arrière-plan : ${message.messageId}');
}

/// Notifications push.
///
/// Rien ici ne doit empêcher l'application de fonctionner : un appareil sans
/// services Google, une configuration Firebase absente, un environnement de
/// test sans greffon natif ou une permission refusée sont des situations
/// normales. Toutes les méthodes échouent en douceur.
class PushMessaging {
  PushMessaging({FirebaseMessaging? messaging}) : _injected = messaging;

  /// Injecté par les tests ; en production il est résolu après l'initialisation
  /// de Firebase. Y toucher trop tôt lèverait une exception avant même que
  /// l'on puisse la rattraper.
  final FirebaseMessaging? _injected;
  FirebaseMessaging? _resolved;

  static const AppLogger _logger = AppLogger('push');
  bool _ready = false;

  /// Prépare Firebase et l'écoute des messages. Sans effet si déjà fait.
  Future<bool> initialize() async {
    if (_ready) {
      return true;
    }
    if (_injected != null) {
      _resolved = _injected;
      _ready = true;
      return true;
    }
    if (!isSupported) {
      _logger.info('Push non pris en charge sur cette plateforme');
      return false;
    }

    try {
      await Firebase.initializeApp();
      _resolved = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
      _ready = true;
      return true;
    } on Object catch (error, stackTrace) {
      // Typiquement : `google-services.json` absent, ou greffon natif indisponible.
      _logger.error('Firebase indisponible', error, stackTrace);
      return false;
    }
  }

  /// Demande l'autorisation d'afficher des notifications.
  ///
  /// Sur Android 13 et au-delà, l'utilisateur doit l'accorder explicitement ;
  /// en deçà elle est acquise. Un refus n'est pas une erreur.
  Future<bool> requestPermission() async {
    if (!await initialize()) {
      return false;
    }
    try {
      final NotificationSettings settings = await _resolved!
          .requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } on Object catch (error, stackTrace) {
      _logger.error('Demande de permission impossible', error, stackTrace);
      return false;
    }
  }

  /// Jeton de cet appareil, ou `null` s'il n'est pas disponible.
  Future<String?> token() async {
    if (!await initialize()) {
      return null;
    }
    try {
      return await _resolved!.getToken();
    } on Object catch (error, stackTrace) {
      _logger.error('Jeton indisponible', error, stackTrace);
      return null;
    }
  }

  /// Émis quand Firebase renouvelle le jeton : il doit être ré-enregistré.
  ///
  /// Flux vide tant que Firebase n'est pas prêt, pour ne jamais lever.
  Stream<String> get onTokenRefresh =>
      _resolved?.onTokenRefresh ?? const Stream<String>.empty();

  /// Messages reçus pendant que l'application est au premier plan.
  Stream<RemoteMessage> get onMessage =>
      _ready ? FirebaseMessaging.onMessage : const Stream<RemoteMessage>.empty();

  /// L'utilisateur a touché la notification et ouvert l'application.
  Stream<RemoteMessage> get onMessageOpenedApp => _ready
      ? FirebaseMessaging.onMessageOpenedApp
      : const Stream<RemoteMessage>.empty();

  /// Notification ayant lancé l'application depuis un état fermé.
  ///
  /// Elle ne passe pas par [onMessageOpenedApp] : le flux n'existait pas
  /// encore au moment du geste. Sans cette lecture, toucher une relance
  /// application fermée ouvrirait l'accueil au lieu de l'écran visé.
  Future<RemoteMessage?> initialMessage() async {
    if (!await initialize()) {
      return null;
    }
    try {
      return await _resolved!.getInitialMessage();
    } on Object catch (error, stackTrace) {
      _logger.error('Message initial illisible', error, stackTrace);
      return null;
    }
  }

  /// Firebase Messaging ne vise ici qu'Android et iOS.
  ///
  /// Le web demanderait une clé VAPID et un service worker ; le bureau n'est
  /// pas pris en charge. Dans ces cas, l'application fonctionne sans push.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
