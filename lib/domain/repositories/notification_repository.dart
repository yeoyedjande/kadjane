import 'package:kadjane/domain/entities/app_notification.dart';

/// Centre de notifications.
abstract interface class NotificationRepository {
  Future<List<AppNotification>> list({
    required String userId,
    String? organizationId,
  });

  Future<int> unreadCount({required String userId, String? organizationId});

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead({required String userId, String? organizationId});

  /// Enregistre le token de push de l'appareil pour le compte connecté.
  Future<void> registerDeviceToken(String token);

  /// Détache l'appareil du compte, à la déconnexion.
  ///
  /// Sans cet appel, le téléphone continuerait de recevoir les relances de
  /// l'utilisateur précédent : Firebase ne renouvelle pas le jeton parce que
  /// la session a pris fin.
  Future<void> unregisterDeviceToken(String token);
}
