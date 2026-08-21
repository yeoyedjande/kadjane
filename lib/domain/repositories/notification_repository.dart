import 'package:kadjane/domain/entities/app_notification.dart';

/// Centre de notifications.
///
/// TODO(api): brancher Firebase Cloud Messaging (enregistrement du token
/// d'appareil, réception en arrière-plan, deep link via `targetRoute`).
abstract interface class NotificationRepository {
  Future<List<AppNotification>> list({
    required String userId,
    String? organizationId,
  });

  Future<int> unreadCount({required String userId, String? organizationId});

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead({required String userId, String? organizationId});

  /// Enregistre le token de push de l'appareil.
  Future<void> registerDeviceToken(String token);
}
