import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';

/// Carte « Prochain tirage » : rappelle les conditions à remplir.
class NextDrawCard extends StatelessWidget {
  const NextDrawCard({
    required this.draw,
    required this.currency,
    required this.onOpen,
    super.key,
  });

  final UpcomingDraw draw;
  final Currency currency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(KSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.accentContainer,
                  borderRadius: BorderRadius.circular(KRadius.sm),
                ),
                child: Icon(
                  Icons.casino_outlined,
                  color: context.colors.accent,
                  size: KSizes.iconMd,
                ),
              ),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.dashboardNextDraw,
                      style: context.text.labelMedium,
                    ),
                    Text(
                      draw.tontineName,
                      style: context.text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              KBadge(
                label: DateFormatter.periodLabel(
                  draw.periodStart,
                  context.localeCode,
                ),
                tone: StatusToneHelper.neutral(context),
              ),
            ],
          ),
          KSpacing.gapLg,
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  label: context.l10n.tontinesPot,
                  value: MoneyFormatter.format(draw.potAmount, currency),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: context.l10n.drawEligibleParticipants,
                  value: '${draw.eligibleCount}',
                ),
              ),
            ],
          ),
          KSpacing.gapLg,
          if (draw.isUnlocked)
            KButton(
              label: context.l10n.drawSpin,
              icon: Icons.play_circle_outline,
              onPressed: onOpen,
            )
          else
            KButton.secondary(
              label: context.l10n.drawUnavailable,
              icon: Icons.lock_outline,
              onPressed: onOpen,
            ),
        ],
      ),
    );
  }
}

/// Carte « Bénéficiaire actuel ».
class CurrentBeneficiaryCard extends StatelessWidget {
  const CurrentBeneficiaryCard({
    required this.beneficiary,
    required this.currency,
    required this.onOpen,
    super.key,
  });

  final CurrentBeneficiaryView beneficiary;
  final Currency currency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          KAvatar(
            name: beneficiary.memberName,
            imageUrl: beneficiary.avatarUrl,
            size: KSizes.avatarLg,
            highlighted: true,
          ),
          const SizedBox(width: KSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.dashboardCurrentBeneficiary,
                  style: context.text.labelMedium,
                ),
                const SizedBox(height: KSpacing.xxs),
                Text(
                  beneficiary.memberName,
                  style: context.text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  '${DateFormatter.periodLabel(beneficiary.periodStart, context.localeCode)} · '
                  '${MoneyFormatter.format(beneficiary.amount, currency)}',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: KSpacing.sm),
                KBadge(
                  label: beneficiary.isPaidOut
                      ? context.l10n.payoutStatusPaid
                      : context.l10n.payoutStatusPending,
                  tone: beneficiary.isPaidOut
                      ? StatusToneHelper.success(context)
                      : StatusToneHelper.warning(context),
                  icon: beneficiary.isPaidOut
                      ? Icons.check_circle_outline
                      : Icons.schedule,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'échéance à venir.
class DeadlineTile extends StatelessWidget {
  const DeadlineTile({
    required this.deadline,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final UpcomingDeadline deadline;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool late = deadline.isLate;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(KSpacing.sm),
        decoration: BoxDecoration(
          color: deadline.isPaid
              ? context.colors.successSurface
              : late
              ? context.colors.dangerSurface
              : context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(KRadius.sm),
        ),
        child: Icon(
          deadline.isPaid ? Icons.check : Icons.event_outlined,
          size: KSizes.iconSm,
          color: deadline.isPaid
              ? context.colors.success
              : late
              ? context.colors.danger
              : context.colors.textSecondary,
        ),
      ),
      title: Text(deadline.tontineName, style: context.text.titleSmall),
      subtitle: Text(
        '${DateFormatter.periodLabel(deadline.periodStart, context.localeCode)} · '
        '${DateFormatter.date(deadline.dueDate, context.localeCode)}',
        style: context.text.bodySmall,
      ),
      trailing: Text(
        MoneyFormatter.compact(deadline.amount, currency),
        style: context.text.titleSmall?.copyWith(
          color: deadline.isPaid
              ? context.colors.success
              : late
              ? context.colors.danger
              : null,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.text.bodySmall),
        const SizedBox(height: KSpacing.xxs),
        Text(
          value,
          style: context.text.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Fabriques de tons pour les badges du dashboard.
