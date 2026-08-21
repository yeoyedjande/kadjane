import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Onglet « Historique » : la frise complète des périodes.
class TontineHistoryTab extends StatelessWidget {
  const TontineHistoryTab({required this.data, super.key});

  final TontineDetailData data;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.xxxl,
      ),
      itemCount: data.cycles.length,
      itemBuilder: (BuildContext context, int index) {
        final TontineCycle cycle = data.cycles[index];
        final Beneficiary? beneficiary = data.beneficiaryOf(cycle.id);
        final Payout? payout = data.payoutOf(cycle.id);
        final bool isLast = index == data.cycles.length - 1;
        final bool done = payout?.isPaid ?? false;
        final bool upcoming = beneficiary == null;

        final Color color = done
            ? context.colors.success
            : upcoming
            ? context.colors.textTertiary
            : context.colors.accent;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: KSpacing.md),
                    decoration: BoxDecoration(
                      color: done ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: context.colors.divider),
                    ),
                ],
              ),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.md),
                  child: KCard(
                    padding: const EdgeInsets.all(KSpacing.md),
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
                        const SizedBox(height: KSpacing.xxs),
                        Text(
                          beneficiary?.memberName ??
                              context.l10n.beneficiaryNone,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xxs),
                        Text(
                          MoneyFormatter.format(
                            cycle.expectedAmount,
                            data.tontine.currency,
                          ),
                          style: context.text.bodySmall,
                        ),
                        const SizedBox(height: KSpacing.sm),
                        Row(
                          children: <Widget>[
                            Icon(
                              done
                                  ? Icons.check_circle
                                  : upcoming
                                  ? Icons.schedule
                                  : Icons.hourglass_bottom,
                              size: 15,
                              color: color,
                            ),
                            const SizedBox(width: KSpacing.xs),
                            Expanded(
                              child: Text(
                                done
                                    ? context.l10n.payoutStatusPaid
                                    : upcoming
                                    ? context.l10n.drawScheduledOn(
                                        DateFormatter.date(
                                          cycle.dueDate,
                                          context.localeCode,
                                        ),
                                      )
                                    : context.l10n.payoutStatusPending,
                                style: context.text.labelSmall?.copyWith(
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
