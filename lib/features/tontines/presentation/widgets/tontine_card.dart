import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';

/// Carte de tontine affichée dans la liste « Mes tontines ».
class TontineCard extends StatelessWidget {
  const TontineCard({required this.summary, required this.onTap, super.key});

  final TontineSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String amount = MoneyFormatter.format(
      summary.tontine.contributionAmount,
      summary.tontine.currency,
    );

    return KCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  summary.tontine.name,
                  style: context.text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KSpacing.sm),
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
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.md,
            runSpacing: KSpacing.xs,
            children: <Widget>[
              _Meta(
                icon: Icons.groups_2_outlined,
                text: context.l10n.tontinesParticipantsCount(
                  summary.participantCount,
                ),
              ),
              _Meta(icon: Icons.payments_outlined, text: amount),
              _Meta(
                icon: Icons.repeat,
                text: Labels.frequency(context.l10n, summary.tontine.frequency),
              ),
            ],
          ),
          KSpacing.gapLg,
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.tontinesPot,
                      style: context.text.labelSmall,
                    ),
                    Text(
                      MoneyFormatter.format(
                        summary.pot,
                        summary.tontine.currency,
                      ),
                      style: context.text.titleMedium?.copyWith(
                        color: context.colors.brand,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    context.l10n.tontinesCyclesCompleted,
                    style: context.text.labelSmall,
                  ),
                  Text(
                    '${summary.completedCycles} / ${summary.totalCycles}',
                    style: context.text.titleMedium,
                  ),
                ],
              ),
            ],
          ),
          KSpacing.gapMd,
          KProgressBar(value: summary.progress),
          if (summary.currentBeneficiaryName != null) ...<Widget>[
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
                    '${context.l10n.dashboardCurrentBeneficiary} : '
                    '${summary.currentBeneficiaryName}',
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: context.colors.textTertiary),
        const SizedBox(width: KSpacing.xs),
        Text(text, style: context.text.bodySmall),
      ],
    );
  }
}
