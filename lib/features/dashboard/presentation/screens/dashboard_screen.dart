import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_trend_chart.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:kadjane/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:kadjane/features/dashboard/presentation/widgets/organization_switcher.dart';
import 'package:kadjane/features/notifications/presentation/providers/notification_providers.dart';

/// Écran d'accueil : la photographie de l'organisation active.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardSnapshot?> snapshot = ref.watch(
      dashboardProvider,
    );
    final User? user = ref.watch(currentUserProvider);
    final int unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: KSpacing.md,
        title: const OrganizationSwitcher(),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.notificationsTitle,
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                const Icon(Icons.notifications_none_rounded),
                if (unread > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: KCountBadge(count: unread),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshOrganizationData(ref),
        child: KAsyncView<DashboardSnapshot?>(
          value: snapshot,
          onRetry: () => ref.invalidate(dashboardProvider),
          isEmpty: (DashboardSnapshot? data) => data == null,
          emptyBuilder: (BuildContext context) =>
              KEmptyState(message: context.l10n.orgCreate),
          builder: (DashboardSnapshot? data) =>
              _DashboardBody(snapshot: data!, userName: user?.firstName ?? ''),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.snapshot, required this.userName});

  final DashboardSnapshot snapshot;
  final String userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Currency currency = snapshot.organization.currency;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.lg,
        KSpacing.xxxl,
      ),
      children: <Widget>[
        Text(
          context.l10n.dashboardGreeting(userName),
          style: context.text.headlineSmall,
        ),
        const SizedBox(height: KSpacing.xs),
        Text(context.l10n.appTagline, style: context.text.bodyMedium),
        KSpacing.gapXl,

        // Progression de la collecte du mois.
        KCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.dashboardCollectionProgress,
                      style: context.text.titleMedium,
                    ),
                  ),
                  if (snapshot.lateContributions > 0)
                    KBadge(
                      label:
                          '${snapshot.lateContributions} ${context.l10n.contributionsLate}',
                      tone: StatusToneHelper.danger(context),
                      icon: Icons.warning_amber_rounded,
                      compact: true,
                    ),
                ],
              ),
              KSpacing.gapLg,
              KAmountProgress(
                collected: snapshot.collectedThisPeriod,
                expected: snapshot.expectedThisPeriod,
                currency: currency,
              ),
              KSpacing.gapLg,
              Row(
                children: <Widget>[
                  _InlineStat(
                    label: context.l10n.dashboardExpectedThisMonth,
                    value: MoneyFormatter.compact(
                      snapshot.expectedThisPeriod,
                      currency,
                    ),
                  ),
                  _InlineStat(
                    label: context.l10n.dashboardCollected,
                    value: MoneyFormatter.compact(
                      snapshot.collectedThisPeriod,
                      currency,
                    ),
                    color: context.colors.success,
                  ),
                  _InlineStat(
                    label: context.l10n.dashboardRemaining,
                    value: MoneyFormatter.compact(
                      snapshot.remainingThisPeriod,
                      currency,
                    ),
                    color: snapshot.remainingThisPeriod > 0
                        ? context.colors.warning
                        : context.colors.success,
                  ),
                ],
              ),
            ],
          ),
        ),
        KSpacing.gapLg,

        KStatGrid(
          tiles: <Widget>[
            KStatTile(
              label: context.l10n.dashboardMembers,
              value: '${snapshot.membersCount}',
              icon: Icons.groups_2_outlined,
              onTap: () => context.push(AppRoutes.members),
            ),
            KStatTile(
              label: context.l10n.dashboardActiveTontines,
              value: '${snapshot.activeTontines}',
              icon: Icons.savings_outlined,
              accent: context.colors.accent,
            ),
            KStatTile(
              label: context.l10n.dashboardMyContribution,
              value: MoneyFormatter.compact(
                snapshot.myContributionDue,
                currency,
              ),
              caption: snapshot.myContributionPaid >= snapshot.myContributionDue
                  ? context.l10n.paymentStatusConfirmed
                  : context.l10n.paymentStatusPending,
              icon: Icons.account_balance_wallet_outlined,
              accent: snapshot.myContributionPaid >= snapshot.myContributionDue
                  ? context.colors.success
                  : context.colors.warning,
              onTap: () => context.go(AppRoutes.contributions),
            ),
            KStatTile(
              label: context.l10n.dashboardLateContributions,
              value: '${snapshot.lateContributions}',
              icon: Icons.report_gmailerrorred_outlined,
              accent: snapshot.lateContributions > 0
                  ? context.colors.danger
                  : context.colors.success,
            ),
          ],
        ),
        KSpacing.gapLg,

        if (snapshot.nextDraw != null) ...<Widget>[
          NextDrawCard(
            draw: snapshot.nextDraw!,
            currency: currency,
            onOpen: () => context.push(
              AppRoutes.tontineDraw(
                snapshot.nextDraw!.tontineId,
                snapshot.nextDraw!.cycleId,
              ),
            ),
          ),
          KSpacing.gapLg,
        ],

        if (snapshot.currentBeneficiary != null) ...<Widget>[
          CurrentBeneficiaryCard(
            beneficiary: snapshot.currentBeneficiary!,
            currency: currency,
            onOpen: () => context.push(
              AppRoutes.tontineBeneficiary(
                snapshot.currentBeneficiary!.tontineId,
                snapshot.currentBeneficiary!.cycleId,
              ),
            ),
          ),
          KSpacing.gapLg,
        ],

        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              KSectionHeader(title: context.l10n.dashboardContributionsTrend),
              KTrendChart(
                currency: currency,
                points: snapshot.trend
                    .map(
                      (TrendPoint point) => ChartPoint(
                        label: DateFormatter.monthShort(
                          point.periodStart,
                          context.localeCode,
                        ),
                        value: point.collected,
                        reference: point.expected,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        KSpacing.gapLg,

        if (snapshot.deadlines.isNotEmpty) ...<Widget>[
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                KSectionHeader(
                  title: context.l10n.dashboardUpcomingDeadlines,
                  actionLabel: context.l10n.commonSeeAll,
                  onAction: () => context.go(AppRoutes.contributions),
                ),
                ...snapshot.deadlines.map(
                  (UpcomingDeadline deadline) => DeadlineTile(
                    deadline: deadline,
                    currency: currency,
                    onTap: () => context.push(
                      AppRoutes.tontineCycle(
                        deadline.tontineId,
                        deadline.cycleId,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          KSpacing.gapLg,
        ],

        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              KSectionHeader(
                title: context.l10n.dashboardRecentActivity,
                actionLabel: context.l10n.commonSeeAll,
                onAction: () => context.go(AppRoutes.activity),
              ),
              if (snapshot.recentActivity.isEmpty)
                Text(context.l10n.activityEmpty, style: context.text.bodyMedium)
              else
                ...snapshot.recentActivity.map(
                  (AuditLog log) => Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: KStatusDot(
                            color: log.isFinancial
                                ? context.colors.success
                                : context.colors.info,
                          ),
                        ),
                        const SizedBox(width: KSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                log.description,
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              Text(
                                DateFormatter.dateTime(
                                  log.createdAt,
                                  context.localeCode,
                                ),
                                style: context.text.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        KSpacing.gapLg,

        KSectionHeader(title: context.l10n.dashboardQuickActions),
        Wrap(
          spacing: KSpacing.md,
          runSpacing: KSpacing.md,
          children: <Widget>[
            _QuickAction(
              icon: Icons.groups_2_outlined,
              label: context.l10n.membersTitle,
              onTap: () => context.push(AppRoutes.members),
            ),
            _QuickAction(
              icon: Icons.account_balance_wallet_outlined,
              label: context.l10n.treasuryTitle,
              onTap: () => context.push(AppRoutes.treasury),
            ),
            _QuickAction(
              icon: Icons.insert_chart_outlined,
              label: context.l10n.reportsTitle,
              onTap: () => context.push(AppRoutes.reports),
            ),
            _QuickAction(
              icon: Icons.settings_outlined,
              label: context.l10n.orgSettingsTitle,
              onTap: () => context.push(AppRoutes.organizationSettings),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: context.text.labelSmall),
          const SizedBox(height: KSpacing.xxs),
          Text(
            value,
            style: context.text.titleSmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KRadius.card,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(
          vertical: KSpacing.lg,
          horizontal: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: KRadius.card,
          border: Border.all(color: context.colors.divider),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: context.colors.brand),
            const SizedBox(height: KSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.text.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
