import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/core/services/push_messaging.dart';
import 'package:kadjane/core/utils/logger.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/features/notifications/presentation/providers/notification_providers.dart';

final Provider<PushMessaging> pushMessagingProvider = Provider<PushMessaging>(
  (Ref ref) => PushMessaging(),
);

/// Rattache l'appareil au compte connecté et écoute les messages entrants.
///
/// Le jeton n'a de sens qu'associé à un utilisateur : on l'enregistre à la
/// connexion, et à chaque renouvellement par Firebase. Aucune de ces étapes ne
/// doit interrompre l'application — un appareil sans services Google ou une
/// permission refusée restent des situations normales.
class PushRegistrar {
  PushRegistrar(this._ref);

  final Ref _ref;
  static const AppLogger _logger = AppLogger('push');

  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  String? _registeredFor;

  Future<void> attach(User user) async {
    if (_registeredFor == user.id) {
      return;
    }
    _registeredFor = user.id;

    final PushMessaging push = _ref.read(pushMessagingProvider);
    if (!await push.requestPermission()) {
      _logger.info('Notifications non autorisées sur cet appareil');
      return;
    }

    final String? token = await push.token();
    if (token != null) {
      await _register(token);
    }

    // Firebase peut renouveler le jeton à tout moment : sans réenregistrement,
    // l'appareil cesserait silencieusement de recevoir les relances.
    await _refreshSubscription?.cancel();
    _refreshSubscription = push.onTokenRefresh.listen(_register);

    // Message reçu application ouverte : Android n'affiche rien de lui-même,
    // on rafraîchit donc la liste et la pastille.
    await _messageSubscription?.cancel();
    _messageSubscription = push.onMessage.listen((RemoteMessage message) {
      _logger.info('Message au premier plan : ${message.messageId}');
      _ref.invalidate(notificationsProvider);
    });
  }

  Future<void> detach() async {
    _registeredFor = null;
    await _refreshSubscription?.cancel();
    await _messageSubscription?.cancel();
    _refreshSubscription = null;
    _messageSubscription = null;
  }

  Future<void> _register(String token) async {
    try {
      await _ref.read(notificationRepositoryProvider).registerDeviceToken(token);
      _logger.info('Appareil enregistré pour les notifications');
    } on Object catch (error, stackTrace) {
      _logger.error('Enregistrement du jeton impossible', error, stackTrace);
    }
  }
}

final Provider<PushRegistrar> pushRegistrarProvider = Provider<PushRegistrar>((
  Ref ref,
) {
  final PushRegistrar registrar = PushRegistrar(ref);
  ref.onDispose(registrar.detach);
  return registrar;
});

/// Suit la session : enregistre à la connexion, détache à la déconnexion.
final Provider<void> pushLifecycleProvider = Provider<void>((Ref ref) {
  final User? user = ref.watch(currentUserProvider);
  final PushRegistrar registrar = ref.read(pushRegistrarProvider);
  if (user == null) {
    unawaited(registrar.detach());
  } else {
    unawaited(registrar.attach(user));
  }
});
