import 'package:kadjane/domain/enums/notification_type.dart';

/// Notification affichée dans le centre de notifications.
///
/// La même entité servira aux notifications push (FCM) : `data` correspond au
/// payload du message.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.organizationId,
    this.readAt,
    this.targetRoute,
    this.data = const <String, String>{},
  });

  final String id;
  final String userId;
  final String? organizationId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Route interne ouverte au tap (deep link).
  final String? targetRoute;
  final Map<String, String> data;

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    organizationId: organizationId,
    readAt: readAt ?? this.readAt,
    targetRoute: targetRoute,
    data: data,
  );
}
