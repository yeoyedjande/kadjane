import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Onglet « Cotisations » : une carte par période.
class TontineCyclesTab extends StatelessWidget {
  const TontineCyclesTab({required this.data, super.key});

  final TontineDetailData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.xxxl,
      ),
      itemCount: data.cycles.length,
      separatorBuilder: (_, _) => KSpacing.gapMd,
      itemBuilder: (BuildContext context, int index) {
        final TontineCycle cycle = data.cycles[index];
        final Beneficiary? beneficiary = data.beneficiaryOf(cycle.id);
        final bool started = !cycle.periodStart.isAfter(DateTime.now());

        return KCard(
          onTap: started
              ? () => context.push(
                  AppRoutes.tontineCycle(data.tontine.id, cycle.id),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          DateFormatter.periodLabel(
                            cycle.periodStart,
                            context.localeCode,
                          ),
                          style: context.text.titleSmall,
                        ),
                        Text(
                          '${context.l10n.tontinesCycle(cycle.index)} · '
                          '${context.l10n.tontinesDueDay} '
                          '${DateFormatter.date(cycle.dueDate, context.localeCode)}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  KBadge(
                    label: _statusLabel(context, cycle),
                    tone: _statusTone(context, cycle),
                    compact: true,
                  ),
                ],
              ),
              if (started) ...<Widget>[
                KSpacing.gapMd,
                KAmountProgress(
                  collected: _collectedOf(cycle),
                  expected: cycle.expectedAmount,
                  currency: data.tontine.currency,
                  compactAmounts: true,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: KSpacing.sm),
                  child: Text(
                    MoneyFormatter.format(
                      cycle.expectedAmount,
                      data.tontine.currency,
                    ),
                    style: context.text.bodyMedium,
                  ),
                ),
              if (beneficiary != null) ...<Widget>[
                KSpacing.gapMd,
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.emoji_events_outlined,
                      size: KSizes.iconSm,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Text(
                        beneficiary.memberName,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      data.payoutOf(cycle.id)?.isPaid ?? false
                          ? context.l10n.payoutStatusPaid
                          : context.l10n.payoutStatusPending,
                      style: context.text.labelSmall?.copyWith(
                        color: data.payoutOf(cycle.id)?.isPaid ?? false
                            ? context.colors.success
                            : context.colors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _collectedOf(TontineCycle cycle) {
    if (data.currentCycle?.id == cycle.id) {
      return data.summary.collectedCurrentCycle;
    }
    // Les cycles clôturés sont intégralement collectés.
    return cycle.status == CycleStatus.closed ||
            cycle.status == CycleStatus.paidOut
        ? cycle.expectedAmount
        : 0;
  }

  String _statusLabel(BuildContext context, TontineCycle cycle) {
    switch (cycle.status) {
      case CycleStatus.upcoming:
        return context.l10n.statusPending;
      case CycleStatus.collecting:
        return context.l10n.contributionsTitle;
      case CycleStatus.readyForDraw:
        return context.l10n.drawSpin;
      case CycleStatus.drawn:
        return context.l10n.beneficiaryStepDraw;
      case CycleStatus.paidOut:
      case CycleStatus.closed:
        return context.l10n.payoutStatusPaid;
    }
  }

  StatusTone _statusTone(BuildContext context, TontineCycle cycle) {
    switch (cycle.status) {
      case CycleStatus.closed:
      case CycleStatus.paidOut:
        return StatusToneHelper.success(context);
      case CycleStatus.readyForDraw:
      case CycleStatus.drawn:
        return StatusToneHelper.info(context);
      case CycleStatus.collecting:
        return StatusToneHelper.warning(context);
      case CycleStatus.upcoming:
        return StatusToneHelper.neutral(context);
    }
  }
}
