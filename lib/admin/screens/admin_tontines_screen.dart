import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/admin/widgets/admin_page.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Supervision des tontines de l'organisation.
class AdminTontinesScreen extends ConsumerWidget {
  const AdminTontinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TontineSummary>> tontines = ref.watch(
      tontineSummariesProvider,
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;

    return AdminPage(
      title: context.l10n.adminNavTontines,
      subtitle: organization?.name,
      child: KAsyncView<List<TontineSummary>>(
        value: tontines,
        onRetry: () => ref.invalidate(tontineSummariesProvider),
        isEmpty: (List<TontineSummary> data) => data.isEmpty,
        emptyBuilder: (BuildContext context) =>
            KEmptyState(message: context.l10n.tontinesEmpty),
        builder: (List<TontineSummary> data) => AdminSection(
          padding: EdgeInsets.zero,
          child: AdminTable(
            columns: <DataColumn>[
              DataColumn(label: Text(context.l10n.tontinesName)),
              DataColumn(label: Text(context.l10n.allocationMode)),
              DataColumn(label: Text(context.l10n.tontinesParticipants)),
              DataColumn(label: Text(context.l10n.tontinesPot)),
              DataColumn(label: Text(context.l10n.tontinesProgress)),
              DataColumn(label: Text(context.l10n.contributionsPeriod)),
              DataColumn(label: Text(context.l10n.commonStatus)),
            ],
            rows: data
                .map(
                  (TontineSummary summary) => DataRow(
                    cells: <DataCell>[
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              summary.tontine.name,
                              style: context.text.titleSmall,
                            ),
                            Text(
                              Labels.frequency(
                                context.l10n,
                                summary.tontine.frequency,
                              ),
                              style: context.text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          Labels.allocationMode(
                            context.l10n,
                            summary.tontine.allocationMode,
                          ),
                        ),
                      ),
                      DataCell(Text('${summary.participantCount}')),
                      DataCell(
                        Text(MoneyFormatter.format(summary.pot, currency)),
                      ),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${summary.completedCycles} / ${summary.totalCycles}',
                                style: context.text.labelSmall,
                              ),
                              const SizedBox(height: KSpacing.xs),
                              KProgressBar(value: summary.progress, height: 6),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          summary.currentCycle == null
                              ? '—'
                              : DateFormatter.periodLabel(
                                  summary.currentCycle!.periodStart,
                                  context.localeCode,
                                ),
                        ),
                      ),
                      DataCell(
                        KBadge(
                          label: Labels.tontineStatus(
                            context.l10n,
                            summary.tontine.status,
                          ),
                          tone: StatusTone.tontine(
                            context.colors,
                            summary.tontine.status,
                          ),
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}
