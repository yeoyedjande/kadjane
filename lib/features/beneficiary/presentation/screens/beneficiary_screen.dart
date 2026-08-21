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
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/features/beneficiary/presentation/widgets/record_payout_sheet.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Bénéficiaire d'une période et suivi du versement.
class BeneficiaryScreen extends ConsumerWidget {
  const BeneficiaryScreen({
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
    final bool canRecordPayout = ref.watch(
      canProvider(Permission.payoutRecord),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.beneficiaryTitle)),
      body: KAsyncView<TontineDetailData>(
        value: detail,
        onRetry: () => ref.invalidate(tontineDetailProvider(tontineId)),
        builder: (TontineDetailData data) {
          final TontineCycle cycle = data.cycles.firstWhere(
            (TontineCycle c) => c.id == cycleId,
            orElse: () => data.cycles.first,
          );
          final Beneficiary? beneficiary = data.beneficiaryOf(cycle.id);
          final Payout? payout = data.payoutOf(cycle.id);

          if (beneficiary == null) {
            return KEmptyState(
              icon: Icons.emoji_events_outlined,
              message: context.l10n.beneficiaryNone,
            );
          }

          final int currentStep = payout?.isPaid ?? false
              ? 5
              : payout != null
              ? 4
              : 3;

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
                  children: <Widget>[
                    KAvatar(
                      name: beneficiary.memberName,
                      imageUrl: beneficiary.avatarUrl,
                      size: KSizes.avatarXl,
                      highlighted: true,
                    ),
                    KSpacing.gapLg,
                    Text(
                      beneficiary.memberName,
                      style: context.text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: KSpacing.xs),
                    Text(
                      DateFormatter.periodLabel(
                        cycle.periodStart,
                        context.localeCode,
                      ),
                      style: context.text.bodyMedium,
                    ),
                    KSpacing.gapLg,
                    Text(
                      MoneyFormatter.format(
                        beneficiary.amount,
                        data.tontine.currency,
                      ),
                      style: context.text.displaySmall?.copyWith(
                        color: context.colors.brand,
                      ),
                    ),
                    KSpacing.gapMd,
                    KBadge(
                      label: payout == null
                          ? context.l10n.payoutStatusPending
                          : Labels.payoutStatus(context.l10n, payout.status),
                      tone: payout == null
                          ? StatusTone(
                              context.colors.warning,
                              context.colors.warningSurface,
                            )
                          : StatusTone.payout(context.colors, payout.status),
                      icon: payout?.isPaid ?? false
                          ? Icons.check_circle_outline
                          : Icons.schedule,
                    ),
                  ],
                ),
              ),
              KSpacing.gapLg,
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    KSectionHeader(title: context.l10n.beneficiaryPayout),
                    KStepTrail(
                      currentIndex: currentStep,
                      steps: <String>[
                        context.l10n.beneficiaryStepContributions,
                        context.l10n.beneficiaryStepPot,
                        context.l10n.beneficiaryStepDraw,
                        context.l10n.beneficiaryStepBeneficiary,
                        context.l10n.beneficiaryStepPayout,
                        context.l10n.beneficiaryStepConfirmation,
                      ],
                    ),
                  ],
                ),
              ),
              KSpacing.gapLg,
              if (payout != null)
                KCard(
                  child: Column(
                    children: <Widget>[
                      KDetailRow(
                        label: context.l10n.beneficiaryAmountSent,
                        value: MoneyFormatter.format(
                          payout.amount,
                          data.tontine.currency,
                        ),
                        icon: Icons.payments_outlined,
                      ),
                      KDetailRow(
                        label: context.l10n.contributionsPaymentMethod,
                        value: payout.method == null
                            ? context.l10n.commonNone
                            : Labels.paymentMethod(
                                context.l10n,
                                payout.method!,
                              ),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      KDetailRow(
                        label: context.l10n.commonDate,
                        value: payout.sentAt == null
                            ? context.l10n.commonNotAvailable
                            : DateFormatter.date(
                                payout.sentAt!,
                                context.localeCode,
                              ),
                        icon: Icons.event_outlined,
                      ),
                      if (payout.reference != null)
                        KDetailRow(
                          label: context.l10n.commonReference,
                          value: payout.reference!,
                          icon: Icons.tag,
                        ),
                    ],
                  ),
                )
              else if (canRecordPayout)
                KButton(
                  label: context.l10n.beneficiaryRecordPayout,
                  icon: Icons.send_outlined,
                  onPressed: () => showKSheet<bool>(
                    context: context,
                    builder: (BuildContext sheetContext) => RecordPayoutSheet(
                      beneficiary: beneficiary,
                      tontineId: tontineId,
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
