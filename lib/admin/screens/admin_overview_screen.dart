import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/admin/router/admin_routes.dart';
import 'package:kadjane/admin/widgets/admin_page.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_trend_chart.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';
import 'package:kadjane/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:kadjane/features/reminders/presentation/providers/reminder_providers.dart';

/// Tableau de bord de pilotage de l'organisation.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardSnapshot?> snapshot = ref.watch(
      dashboardProvider,
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final List<DunningTarget> targets =
        ref.watch(organizationDunningProvider).valueOrNull ??
        const <DunningTarget>[];
    final Currency currency = organization?.currency ?? Currency.xof;

    return AdminPage(
      title: context.l10n.adminNavOverview,
      subtitle: organization?.name,
      actions: <Widget>[
        KButton.secondary(
          label: context.l10n.commonRefresh,
          icon: Icons.refresh,
          expanded: false,
          onPressed: () {
            ref
              ..invalidate(dashboardProvider)
              ..invalidate(organizationDunningProvider);
          },
        ),
        KButton(
          label: context.l10n.remindersCenter,
          icon: Icons.campaign_outlined,
          expanded: false,
          onPressed: () => context.go(AdminRoutes.reminders),
        ),
      ],
      child: KAsyncView<DashboardSnapshot?>(
        value: snapshot,
        onRetry: () => ref.invalidate(dashboardProvider),
        isEmpty: (DashboardSnapshot? data) => data == null,
        builder: (DashboardSnapshot? data) {
          final DashboardSnapshot d = data!;
          final int blockedDraws = d.nextDraw == null || d.nextDraw!.isUnlocked
              ? 0
              : 1;
          final int pendingPayout =
              d.currentBeneficiary != null && !d.currentBeneficiary!.isPaidOut
              ? 1
              : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              KStatGrid(
                columns: 4,
                tiles: <Widget>[
                  KStatTile(
                    label: context.l10n.dashboardMembers,
                    value: '${d.membersCount}',
                    icon: Icons.groups_2_outlined,
                    onTap: () => context.go(AdminRoutes.members),
                  ),
                  KStatTile(
                    label: context.l10n.dashboardActiveTontines,
                    value: '${d.activeTontines}',
                    icon: Icons.savings_outlined,
                    accent: context.colors.accent,
                    onTap: () => context.go(AdminRoutes.tontines),
                  ),
                  KStatTile(
                    label: context.l10n.adminCollectionRate,
                    value: MoneyFormatter.percent(d.collectionProgress),
                    icon: Icons.percent,
                    accent: d.collectionProgress >= 1
                        ? context.colors.success
                        : context.colors.brand,
                  ),
                  KStatTile(
                    label: context.l10n.adminOutstanding,
                    value: MoneyFormatter.compact(
                      d.remainingThisPeriod,
                      currency,
                    ),
                    icon: Icons.warning_amber_outlined,
                    accent: d.remainingThisPeriod > 0
                        ? context.colors.warning
                        : context.colors.success,
                    caption: targets.isEmpty
                        ? null
                        : context.l10n.remindersToRemind,
                  ),
                ],
              ),
              KSpacing.gapXl,

              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth > 900;
                  final Widget progress = AdminSection(
                    title: context.l10n.dashboardCollectionProgress,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        KAmountProgress(
                          collected: d.collectedThisPeriod,
                          expected: d.expectedThisPeriod,
                          currency: currency,
                        ),
                        KSpacing.gapXl,
                        KTrendChart(
                          currency: currency,
                          points: d.trend
                              .map(
                                (TrendPoint p) => ChartPoint(
                                  label: DateFormatter.monthShort(
                                    p.periodStart,
                                    context.localeCode,
                                  ),
                                  value: p.collected,
                                  reference: p.expected,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  );
                  final Widget alerts = AdminSection(
                    title: context.l10n.adminAlerts,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (d.lateContributions == 0 &&
                            blockedDraws == 0 &&
                            pendingPayout == 0)
                          Text(
                            context.l10n.adminNoAlerts,
                            style: context.text.bodyMedium,
                          ),
                        if (d.lateContributions > 0)
                          _Alert(
                            icon: Icons.person_off_outlined,
                            tone: StatusToneHelper.danger(context),
                            label: context.l10n.adminAlertLateMembers(
                              d.lateContributions,
                            ),
                            actionLabel: context.l10n.remindersSendShort,
                            onAction: () => context.go(AdminRoutes.reminders),
                          ),
                        if (blockedDraws > 0)
                          _Alert(
                            icon: Icons.lock_outline,
                            tone: StatusToneHelper.warning(context),
                            label: context.l10n.adminAlertBlockedDraw(
                              blockedDraws,
                            ),
                          ),
                        if (pendingPayout > 0)
                          _Alert(
                            icon: Icons.payments_outlined,
                            tone: StatusToneHelper.info(context),
                            label: context.l10n.adminAlertPendingPayout(
                              pendingPayout,
                            ),
                          ),
                      ],
                    ),
                  );

                  if (!wide) {
                    return Column(
                      children: <Widget>[progress, KSpacing.gapLg, alerts],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: progress),
                      const SizedBox(width: KSpacing.lg),
                      Expanded(flex: 2, child: alerts),
                    ],
                  );
                },
              ),
              KSpacing.gapXl,

              AdminSection(
                title: context.l10n.dashboardRecentActivity,
                padding: EdgeInsets.zero,
                child: AdminTable(
                  emptyLabel: context.l10n.activityEmpty,
                  columns: <DataColumn>[
                    DataColumn(label: Text(context.l10n.commonDate)),
                    DataColumn(label: Text(context.l10n.activityTitle)),
                    DataColumn(label: Text(context.l10n.commonAmount)),
                  ],
                  rows: d.recentActivity
                      .map(
                        (dynamic log) => DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Text(
                                DateFormatter.dateTime(
                                  log.createdAt as DateTime,
                                  context.localeCode,
                                ),
                              ),
                            ),
                            DataCell(Text(log.description as String)),
                            DataCell(
                              Text(
                                log.amount == null
                                    ? '—'
                                    : MoneyFormatter.format(
                                        log.amount as double,
                                        currency,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.icon,
    required this.tone,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final StatusTone tone;
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: KRadius.field,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: KSizes.iconSm, color: tone.foreground),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(color: tone.foreground),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
