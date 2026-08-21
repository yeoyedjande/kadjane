import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/features/activity/presentation/providers/activity_providers.dart';

/// Journal d'activité et d'audit de l'organisation.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AuditLog>> logs = ref.watch(activityLogsProvider);
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.activityTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(
              left: KSpacing.lg,
              bottom: KSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.activityAudit,
                style: context.text.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(activityLogsProvider),
        child: KAsyncView<List<AuditLog>>(
          value: logs,
          onRetry: () => ref.invalidate(activityLogsProvider),
          isEmpty: (List<AuditLog> data) => data.isEmpty,
          emptyBuilder: (BuildContext context) => KEmptyState(
            icon: Icons.timeline_outlined,
            message: context.l10n.activityEmpty,
          ),
          builder: (List<AuditLog> data) {
            final Map<String, List<AuditLog>> grouped =
                <String, List<AuditLog>>{};
            for (final AuditLog log in data) {
              grouped
                  .putIfAbsent(_bucket(context, log.createdAt), () {
                    return <AuditLog>[];
                  })
                  .add(log);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.sm,
                KSpacing.lg,
                KSpacing.xxxl,
              ),
              children: grouped.entries
                  .map(
                    (MapEntry<String, List<AuditLog>> entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: KSpacing.md,
                          ),
                          child: Text(
                            entry.key,
                            style: context.text.labelMedium,
                          ),
                        ),
                        ...entry.value.map(
                          (AuditLog log) => Padding(
                            padding: const EdgeInsets.only(bottom: KSpacing.sm),
                            child: KCard(
                              padding: const EdgeInsets.all(KSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(KSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: log.isFinancial
                                          ? context.colors.successSurface
                                          : context.colors.infoSurface,
                                      borderRadius: BorderRadius.circular(
                                        KRadius.sm,
                                      ),
                                    ),
                                    child: Icon(
                                      log.isFinancial
                                          ? Icons.payments_outlined
                                          : Icons.bolt_outlined,
                                      size: KSizes.iconSm,
                                      color: log.isFinancial
                                          ? context.colors.success
                                          : context.colors.info,
                                    ),
                                  ),
                                  const SizedBox(width: KSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          log.description,
                                          style: context.text.bodyMedium
                                              ?.copyWith(
                                                color:
                                                    context.colors.textPrimary,
                                              ),
                                        ),
                                        const SizedBox(height: KSpacing.xxs),
                                        Text(
                                          '${DateFormatter.dateTime(log.createdAt, context.localeCode)} · ${log.actorName}',
                                          style: context.text.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (log.amount != null) ...<Widget>[
                                    const SizedBox(width: KSpacing.sm),
                                    Text(
                                      MoneyFormatter.compact(
                                        log.amount!,
                                        currency,
                                      ),
                                      style: context.text.labelMedium?.copyWith(
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }

  String _bucket(BuildContext context, DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(date.year, date.month, date.day);
    if (day == today) {
      return context.l10n.activityToday;
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return context.l10n.activityYesterday;
    }
    return context.l10n.activityEarlier;
  }
}
