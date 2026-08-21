import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/features/reminders/presentation/providers/reminder_providers.dart';

/// Relances reçues par le membre, dans son espace « Mes cotisations ».
class MyRemindersCard extends ConsumerWidget {
  const MyRemindersCard({super.key});

  StatusTone _tone(BuildContext context, ReminderLevel level) {
    switch (level) {
      case ReminderLevel.upcoming:
        return StatusTone(context.colors.info, context.colors.infoSurface);
      case ReminderLevel.dueToday:
        return StatusTone(
          context.colors.warning,
          context.colors.warningSurface,
        );
      case ReminderLevel.late_:
      case ReminderLevel.escalated:
        return StatusTone(context.colors.danger, context.colors.dangerSurface);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Reminder> reminders =
        ref.watch(myRemindersProvider).valueOrNull ?? const <Reminder>[];
    final List<Reminder> visible = reminders
        .where((Reminder r) => r.isDelivered)
        .take(4)
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    final int unread = ref.watch(myUnreadRemindersProvider).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.lg),
      child: KCard(
        borderColor: unread > 0 ? context.colors.warning : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.campaign_outlined,
                  size: KSizes.iconMd,
                  color: context.colors.warning,
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Text(
                    context.l10n.remindersMine,
                    style: context.text.titleMedium,
                  ),
                ),
                if (unread > 0) KCountBadge(count: unread),
              ],
            ),
            KSpacing.gapMd,
            ...visible.map(
              (Reminder reminder) => Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.md),
                child: InkWell(
                  onTap: reminder.isRead
                      ? null
                      : () async {
                          await ref
                              .read(reminderRepositoryProvider)
                              .markAsRead(reminder.id);
                          ref.invalidate(myRemindersProvider);
                        },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          KBadge(
                            label: Labels.reminderLevel(
                              context.l10n,
                              reminder.level,
                            ),
                            tone: _tone(context, reminder.level),
                            compact: true,
                          ),
                          const SizedBox(width: KSpacing.sm),
                          Icon(
                            Labels.reminderChannelIcon(reminder.channel),
                            size: 14,
                            color: context.colors.textTertiary,
                          ),
                          const Spacer(),
                          Text(
                            DateFormatter.date(
                              reminder.createdAt,
                              context.localeCode,
                            ),
                            style: context.text.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        reminder.message,
                        style: context.text.bodySmall?.copyWith(
                          color: reminder.isRead
                              ? context.colors.textSecondary
                              : context.colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
