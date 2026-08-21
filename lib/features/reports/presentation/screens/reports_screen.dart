import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/repositories/report_repository.dart';

/// Rapports consolidés de l'organisation.
final AutoDisposeFutureProvider<ReportSnapshot?> reportProvider =
    FutureProvider.autoDispose<ReportSnapshot?>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return null;
      }
      return ref.watch(reportRepositoryProvider).load(organizationId);
    });

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ReportFormat format,
  ) async {
    final String? organizationId = ref
        .read(activeOrganizationIdProvider)
        .valueOrNull;
    if (organizationId == null) {
      return;
    }
    await ref
        .read(reportRepositoryProvider)
        .export(organizationId: organizationId, format: format);
    if (context.mounted) {
      context.showMessage(context.l10n.reportsExportMocked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReportSnapshot?> report = ref.watch(reportProvider);
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reportsTitle)),
      body: KAsyncView<ReportSnapshot?>(
        value: report,
        onRetry: () => ref.invalidate(reportProvider),
        isEmpty: (ReportSnapshot? data) => data == null,
        builder: (ReportSnapshot? data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xxxl,
          ),
          children: <Widget>[
            KStatGrid(
              tiles: <Widget>[
                KStatTile(
                  label: context.l10n.reportsTotalContributions,
                  value: MoneyFormatter.compact(data!.totalCollected, currency),
                  icon: Icons.savings_outlined,
                  accent: context.colors.success,
                ),
                KStatTile(
                  label: context.l10n.reportsUnpaid,
                  value: MoneyFormatter.compact(data.unpaid, currency),
                  icon: Icons.warning_amber_outlined,
                  accent: context.colors.warning,
                ),
                KStatTile(
                  label: context.l10n.reportsDistributed,
                  value: MoneyFormatter.compact(
                    data.totalDistributed,
                    currency,
                  ),
                  icon: Icons.payments_outlined,
                  accent: context.colors.accent,
                ),
                KStatTile(
                  label: context.l10n.reportsRecoveryRate,
                  value: MoneyFormatter.percent(data.recoveryRate),
                  icon: Icons.percent,
                ),
              ],
            ),
            KSpacing.gapLg,
            KStatGrid(
              tiles: <Widget>[
                KStatTile(
                  label: context.l10n.dashboardMembers,
                  value: '${data.membersCount}',
                  icon: Icons.groups_2_outlined,
                ),
                KStatTile(
                  label: context.l10n.dashboardActiveTontines,
                  value: '${data.activeTontines}',
                  icon: Icons.event_repeat_outlined,
                ),
              ],
            ),
            KSpacing.gapLg,
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  KSectionHeader(title: context.l10n.tontinesTitle),
                  ...data.lines.map(
                    (TontineReportLine line) => Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  line.tontineName,
                                  style: context.text.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                MoneyFormatter.percent(line.recoveryRate),
                                style: context.text.labelMedium?.copyWith(
                                  color: context.colors.brand,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: KSpacing.sm),
                          KProgressBar(value: line.recoveryRate),
                          const SizedBox(height: KSpacing.xs),
                          Text(
                            '${MoneyFormatter.compact(line.collected, currency)} / '
                            '${MoneyFormatter.compact(line.expected, currency)}',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.gapLg,
            Row(
              children: <Widget>[
                Expanded(
                  child: KButton.secondary(
                    label: context.l10n.reportsExportPdf,
                    icon: Icons.picture_as_pdf_outlined,
                    size: KButtonSize.small,
                    onPressed: () => _export(context, ref, ReportFormat.pdf),
                  ),
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: KButton.secondary(
                    label: context.l10n.reportsExportExcel,
                    icon: Icons.table_chart_outlined,
                    size: KButtonSize.small,
                    onPressed: () => _export(context, ref, ReportFormat.excel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
