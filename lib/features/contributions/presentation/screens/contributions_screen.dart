import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/features/contributions/presentation/providers/contribution_providers.dart';
import 'package:kadjane/features/reminders/presentation/widgets/my_reminders_card.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// « Mes cotisations » : ce que le membre connecté a versé et doit encore.
class ContributionsScreen extends ConsumerWidget {
  const ContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Contribution>> contributions = ref.watch(
      myContributionsProvider,
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;
    final List<TontineSummary> tontines =
        ref.watch(tontineSummariesProvider).valueOrNull ??
        const <TontineSummary>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.contributionsMine)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myContributionsProvider),
        child: KAsyncView<List<Contribution>>(
          value: contributions,
          onRetry: () => ref.invalidate(myContributionsProvider),
          isEmpty: (List<Contribution> data) => data.isEmpty,
          emptyBuilder: (BuildContext context) => KEmptyState(
            icon: Icons.receipt_long_outlined,
            message: context.l10n.contributionsEmpty,
          ),
          builder: (List<Contribution> data) {
            final double totalPaid = data
                .where((Contribution c) => c.countsAsCollected)
                .fold<double>(
                  0,
                  (double sum, Contribution c) => sum + c.amount,
                );
            final int pending = data
                .where(
                  (Contribution c) => c.status == ContributionStatus.pending,
                )
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.sm,
                KSpacing.lg,
                KSpacing.xxxl,
              ),
              children: <Widget>[
                const MyRemindersCard(),
                KStatGrid(
                  columns: 3,
                  tiles: <Widget>[
                    KStatTile(
                      label: context.l10n.contributionsTotalPaid,
                      value: MoneyFormatter.compact(totalPaid, currency),
                      icon: Icons.check_circle_outline,
                      accent: context.colors.success,
                    ),
                    KStatTile(
                      label: context.l10n.contributionsPaymentsCount,
                      value: '${data.length}',
                      icon: Icons.receipt_long_outlined,
                    ),
                    KStatTile(
                      label: context.l10n.paymentStatusPending,
                      value: '$pending',
                      icon: Icons.schedule,
                      accent: context.colors.warning,
                    ),
                  ],
                ),
                KSpacing.gapLg,
                KSectionHeader(
                  title: context.l10n.tontinesTitle,
                  actionLabel: context.l10n.commonSeeAll,
                  onAction: () => context.go(AppRoutes.tontines),
                ),
                ...tontines.map(
                  (TontineSummary summary) => Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.sm),
                    child: KCard(
                      padding: const EdgeInsets.all(KSpacing.md),
                      onTap: () => context.push(
                        AppRoutes.tontineDetail(summary.tontine.id),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  summary.tontine.name,
                                  style: context.text.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  summary.currentCycle == null
                                      ? context.l10n.commonNotAvailable
                                      : DateFormatter.periodLabel(
                                          summary.currentCycle!.periodStart,
                                          context.localeCode,
                                        ),
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            MoneyFormatter.format(
                              summary.tontine.contributionAmount,
                              summary.tontine.currency,
                            ),
                            style: context.text.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                KSpacing.gapLg,
                KSectionHeader(title: context.l10n.contributionsTitle),
                ...data.map(
                  (Contribution contribution) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(KSpacing.sm),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(KRadius.sm),
                          ),
                          child: Icon(
                            contribution.method == null
                                ? Icons.payments_outlined
                                : Labels.paymentIcon(contribution.method!),
                            size: KSizes.iconSm,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: KSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                DateFormatter.date(
                                  contribution.paidAt ??
                                      contribution.recordedAt,
                                  context.localeCode,
                                ),
                                style: context.text.titleSmall,
                              ),
                              if (contribution.method != null)
                                Text(
                                  Labels.paymentMethod(
                                    context.l10n,
                                    contribution.method!,
                                  ),
                                  style: context.text.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          MoneyFormatter.format(contribution.amount, currency),
                          style: context.text.titleSmall,
                        ),
                        const SizedBox(width: KSpacing.md),
                        KBadge(
                          label: Labels.contributionStatus(
                            context.l10n,
                            contribution.status,
                          ),
                          tone: StatusTone.contribution(
                            context.colors,
                            contribution.status,
                          ),
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
