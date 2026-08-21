import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/user.dart';

/// Notifications de l'utilisateur pour l'organisation active.
final AutoDisposeFutureProvider<List<AppNotification>> notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((Ref ref) async {
      final User? user = ref.watch(currentUserProvider);
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (user == null) {
        return const <AppNotification>[];
      }
      return ref
          .watch(notificationRepositoryProvider)
          .list(userId: user.id, organizationId: organizationId);
    });

/// Nombre de notifications non lues (pastille de la cloche).
final AutoDisposeFutureProvider<int> unreadNotificationsProvider =
    FutureProvider.autoDispose<int>((Ref ref) async {
      final List<AppNotification> notifications = await ref.watch(
        notificationsProvider.future,
      );
      return notifications.where((AppNotification n) => !n.isRead).length;
    });
