import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/features/contributions/presentation/providers/contribution_providers.dart';
import 'package:kadjane/features/contributions/presentation/widgets/record_payment_sheet.dart';
import 'package:kadjane/features/reminders/presentation/widgets/quick_remind_button.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Cotisations d'une période : qui a payé, qui reste à encaisser.
class CycleContributionsScreen extends ConsumerWidget {
  const CycleContributionsScreen({
    required this.tontineId,
    required this.cycleId,
    super.key,
  });

  final String tontineId;
  final String cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TontineDetailData> detail = ref.watch(
      tontineDetailProvider(tontineId),
    );
    final AsyncValue<List<ContributionSlot>> slots = ref.watch(
      cycleSlotsProvider(cycleId),
    );
    final bool canRecord = ref.watch(
      canProvider(Permission.contributionRecord),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.contributionsTitle),
        actions: <Widget>[
          QuickRemindButton(tontineId: tontineId, cycleId: cycleId),
        ],
      ),
      body: KAsyncView<TontineDetailData>(
        value: detail,
        onRetry: () => ref.invalidate(tontineDetailProvider(tontineId)),
        builder: (TontineDetailData data) {
          final TontineCycle cycle = data.cycles.firstWhere(
            (TontineCycle c) => c.id == cycleId,
            orElse: () => data.cycles.first,
          );

          return KAsyncView<List<ContributionSlot>>(
            value: slots,
            onRetry: () => ref.invalidate(cycleSlotsProvider(cycleId)),
            builder: (List<ContributionSlot> data2) {
              final double collected = data2.fold<double>(
                0,
                (double sum, ContributionSlot slot) => sum + slot.paidAmount,
              );
              final int paid = data2
                  .where((ContributionSlot slot) => slot.isPaid)
                  .length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.lg,
                  KSpacing.sm,
                  KSpacing.lg,
                  KSpacing.xxxl,
                ),
                children: <Widget>[
                  KCard(
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          DateFormatter.periodLabel(
                            cycle.periodStart,
                            context.localeCode,
                          ),
                          style: context.text.titleLarge,
                        ),
                        Text(data.tontine.name, style: context.text.bodySmall),
                        KSpacing.gapLg,
                        KAmountProgress(
                          collected: collected,
                          expected: cycle.expectedAmount,
                          currency: data.tontine.currency,
                        ),
                        KSpacing.gapMd,
                        Text(
                          context.l10n.contributionsPaidMembers(
                            paid,
                            data2.length,
                          ),
                          style: context.text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  KSpacing.gapLg,
                  ...data2.map(
                    (ContributionSlot slot) => _SlotTile(
                      slot: slot,
                      currency: data.tontine.currency.code,
                      canRecord: canRecord,
                      onRecord: () => showKSheet<bool>(
                        context: context,
                        builder: (BuildContext sheetContext) =>
                            RecordPaymentSheet(
                              tontineId: tontineId,
                              cycleId: cycleId,
                              memberId: slot.memberId,
                              memberName: slot.memberName,
                              expectedAmount: slot.expectedAmount,
                            ),
                      ),
                      amountLabel: MoneyFormatter.format(
                        slot.expectedAmount,
                        data.tontine.currency,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.currency,
    required this.canRecord,
    required this.onRecord,
    required this.amountLabel,
  });

  final ContributionSlot slot;
  final String currency;
  final bool canRecord;
  final VoidCallback onRecord;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Row(
        children: <Widget>[
          KAvatar(name: slot.memberName, imageUrl: slot.avatarUrl),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  slot.memberName,
                  style: context.text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(amountLabel, style: context.text.bodySmall),
              ],
            ),
          ),
          if (slot.status != null)
            KBadge(
              label: Labels.contributionStatus(context.l10n, slot.status!),
              tone: StatusTone.contribution(context.colors, slot.status!),
              compact: true,
            )
          else if (canRecord)
            KButton.ghost(
              label: context.l10n.commonAdd,
              icon: Icons.add,
              onPressed: onRecord,
            )
          else
            KBadge(
              label: context.l10n.paymentStatusPending,
              tone: StatusTone(
                context.colors.warning,
                context.colors.warningSurface,
              ),
              compact: true,
            ),
        ],
      ),
    );
  }
}
