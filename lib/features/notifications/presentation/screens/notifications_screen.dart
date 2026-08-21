import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/features/notifications/presentation/providers/notification_providers.dart';

/// Centre de notifications.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> notifications = ref.watch(
      notificationsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsTitle),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final User? user = ref.read(currentUserProvider);
              final String? organizationId = ref
                  .read(activeOrganizationIdProvider)
                  .valueOrNull;
              if (user == null) {
                return;
              }
              await ref
                  .read(notificationRepositoryProvider)
                  .markAllAsRead(
                    userId: user.id,
                    organizationId: organizationId,
                  );
              ref.invalidate(notificationsProvider);
            },
            child: Text(context.l10n.notificationsMarkAllRead),
          ),
        ],
      ),
      body: KAsyncView<List<AppNotification>>(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        isEmpty: (List<AppNotification> data) => data.isEmpty,
        emptyBuilder: (BuildContext context) => KEmptyState(
          icon: Icons.notifications_none_rounded,
          message: context.l10n.notificationsEmpty,
        ),
        builder: (List<AppNotification> data) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xxxl,
          ),
          itemCount: data.length,
          separatorBuilder: (_, _) => KSpacing.gapSm,
          itemBuilder: (BuildContext context, int index) {
            final AppNotification notification = data[index];
            return KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              color: notification.isRead
                  ? null
                  : context.scheme.primaryContainer.withValues(alpha: 0.35),
              onTap: () async {
                await ref
                    .read(notificationRepositoryProvider)
                    .markAsRead(notification.id);
                ref.invalidate(notificationsProvider);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(KSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(KRadius.sm),
                    ),
                    child: Icon(
                      Labels.notificationIcon(notification.type),
                      size: KSizes.iconSm,
                      color: context.colors.brand,
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          notification.title,
                          style: context.text.titleSmall,
                        ),
                        const SizedBox(height: KSpacing.xxs),
                        Text(notification.body, style: context.text.bodySmall),
                        const SizedBox(height: KSpacing.xs),
                        Text(
                          DateFormatter.dateTime(
                            notification.createdAt,
                            context.localeCode,
                          ),
                          style: context.text.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: KSpacing.xs),
                      decoration: BoxDecoration(
                        color: context.colors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
