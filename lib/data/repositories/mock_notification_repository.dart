import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/repositories/notification_repository.dart';

/// TODO(api): remplacer par `RestNotificationRepository` + Firebase Cloud
/// Messaging (token d'appareil, réception en arrière-plan, deep links).
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<AppNotification>> list({
    required String userId,
    String? organizationId,
  }) => _db.withLatency(() {
    final List<AppNotification> list = _db.notifications
        .where(
          (AppNotification n) =>
              n.userId == userId &&
              (organizationId == null || n.organizationId == organizationId),
        )
        .toList();
    list.sort(
      (AppNotification a, AppNotification b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return List<AppNotification>.unmodifiable(list);
  });

  @override
  Future<int> unreadCount({required String userId, String? organizationId}) =>
      _db.withLatency(
        () => _db.notifications
            .where(
              (AppNotification n) =>
                  n.userId == userId &&
                  !n.isRead &&
                  (organizationId == null ||
                      n.organizationId == organizationId),
            )
            .length,
      );

  @override
  Future<void> markAsRead(String notificationId) => _db.withLatency(() {
    final int index = _db.notifications.indexWhere(
      (AppNotification n) => n.id == notificationId,
    );
    if (index != -1) {
      _db.notifications[index] = _db.notifications[index].copyWith(
        readAt: DateTime.now(),
      );
    }
  });

  @override
  Future<void> markAllAsRead({
    required String userId,
    String? organizationId,
  }) => _db.withLatency(() {
    for (int i = 0; i < _db.notifications.length; i++) {
      final AppNotification n = _db.notifications[i];
      final bool matches =
          n.userId == userId &&
          (organizationId == null || n.organizationId == organizationId);
      if (matches && !n.isRead) {
        _db.notifications[i] = n.copyWith(readAt: DateTime.now());
      }
    }
  });

  @override
  Future<void> registerDeviceToken(String token) async {
    // TODO(api): POST /notifications/devices avec le token FCM.
  }
}
