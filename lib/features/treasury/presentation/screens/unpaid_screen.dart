import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/features/treasury/presentation/providers/treasury_providers.dart';

/// Impayés : membre, cotisation, dû, payé, reste, jours de retard.
///
/// Les exemptions n'y figurent pas — elles ne sont plus attendues, ce ne sont
/// pas des impayés, et les compter fausserait le recouvrement.
class UnpaidScreen extends ConsumerWidget {
  const UnpaidScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CampaignEntry>> unpaid = ref.watch(unpaidProvider);
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.unpaidTitle)),
      body: KAsyncView<List<CampaignEntry>>(
        value: unpaid,
        onRetry: () => ref.invalidate(unpaidProvider),
        isEmpty: (List<CampaignEntry> data) => data.isEmpty,
        emptyBuilder: (BuildContext context) => KEmptyState(
          icon: Icons.check_circle_outline,
          message: context.l10n.unpaidEmpty,
        ),
        builder: (List<CampaignEntry> data) {
          final double outstanding = data.fold<double>(
            0,
            (double sum, CampaignEntry entry) => sum + entry.remainingAmount,
          );
          final int lateCount = data
              .where(
                (CampaignEntry entry) =>
                    entry.status == CampaignEntryStatus.late_,
              )
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.giant,
            ),
            children: <Widget>[
              KStatGrid(
                columns: 2,
                tiles: <Widget>[
                  KStatTile(
                    label: context.l10n.treasuryRemaining,
                    value: MoneyFormatter.compact(outstanding, currency),
                    icon: Icons.hourglass_bottom,
                    accent: context.colors.danger,
                  ),
                  KStatTile(
                    label: context.l10n.treasuryLate,
                    value: '$lateCount',
                    icon: Icons.warning_amber_outlined,
                  ),
                ],
              ),
              KSpacing.gapLg,
              ...data.map(
                (CampaignEntry entry) => Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: KCard(
                    padding: const EdgeInsets.all(KSpacing.md),
                    onTap: () =>
                        context.push(AppRoutes.campaignDetail(entry.campaignId)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.memberName,
                          style: context.text.titleSmall,
                        ),
                        const SizedBox(height: KSpacing.xxs),
                        Text(
                          entry.campaignTitle ?? '',
                          style: context.text.bodySmall,
                        ),
                        const SizedBox(height: KSpacing.xs),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                context.l10n.campaignPaidOf(
                                  MoneyFormatter.format(
                                    entry.paidAmount,
                                    currency,
                                  ),
                                  MoneyFormatter.format(
                                    entry.expectedAmount,
                                    currency,
                                  ),
                                ),
                                style: context.text.labelMedium,
                              ),
                            ),
                            Text(
                              MoneyFormatter.format(
                                entry.remainingAmount,
                                currency,
                              ),
                              style: context.text.titleSmall?.copyWith(
                                color: context.colors.danger,
                              ),
                            ),
                          ],
                        ),
                        if (entry.dueDate != null || entry.daysLate > 0) ...<Widget>[
                          const SizedBox(height: KSpacing.xxs),
                          Text(
                            entry.daysLate > 0
                                ? context.l10n.unpaidDaysLate(entry.daysLate)
                                : DateFormatter.date(
                                    entry.dueDate!,
                                    context.localeCode,
                                  ),
                            style: context.text.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
