import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/admin/widgets/admin_page.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/features/activity/presentation/providers/activity_providers.dart';

/// Journal d'audit complet, filtrable sur les seules opérations financières.
class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  bool _financialOnly = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AuditLog>> logs = ref.watch(activityLogsProvider);
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;

    return AdminPage(
      title: context.l10n.activityAudit,
      subtitle: context.l10n.remindersAudited,
      actions: <Widget>[
        FilterChip(
          selected: _financialOnly,
          label: Text(context.l10n.treasuryTitle),
          avatar: const Icon(Icons.payments_outlined, size: 16),
          onSelected: (bool value) => setState(() => _financialOnly = value),
        ),
        KButton.secondary(
          label: context.l10n.commonRefresh,
          icon: Icons.refresh,
          expanded: false,
          onPressed: () => ref.invalidate(activityLogsProvider),
        ),
      ],
      child: KAsyncView<List<AuditLog>>(
        value: logs,
        onRetry: () => ref.invalidate(activityLogsProvider),
        isEmpty: (List<AuditLog> data) => data.isEmpty,
        emptyBuilder: (BuildContext context) =>
            KEmptyState(message: context.l10n.activityEmpty),
        builder: (List<AuditLog> data) {
          final List<AuditLog> filtered = _financialOnly
              ? data.where((AuditLog log) => log.isFinancial).toList()
              : data;

          return AdminSection(
            padding: EdgeInsets.zero,
            child: AdminTable(
              emptyLabel: context.l10n.activityEmpty,
              columns: <DataColumn>[
                DataColumn(label: Text(context.l10n.commonDate)),
                DataColumn(label: Text(context.l10n.drawLaunchedBy)),
                DataColumn(label: Text(context.l10n.activityTitle)),
                DataColumn(label: Text(context.l10n.commonAmount)),
                DataColumn(label: Text(context.l10n.commonReference)),
              ],
              rows: filtered
                  .map(
                    (AuditLog log) => DataRow(
                      cells: <DataCell>[
                        DataCell(
                          Text(
                            DateFormatter.dateTime(
                              log.createdAt,
                              context.localeCode,
                            ),
                          ),
                        ),
                        DataCell(Text(log.actorName)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Row(
                              children: <Widget>[
                                if (log.isFinancial) ...<Widget>[
                                  KStatusDot(color: context.colors.success),
                                  const SizedBox(width: KSpacing.sm),
                                ],
                                Flexible(child: Text(log.description)),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            log.amount == null
                                ? '—'
                                : MoneyFormatter.format(log.amount!, currency),
                          ),
                        ),
                        DataCell(
                          Text(log.action.code, style: context.text.labelSmall),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        },
      ),
    );
  }
}
