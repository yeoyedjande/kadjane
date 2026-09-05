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
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Onglet « Vue d'ensemble » : cagnotte, progression, position du membre.
class TontineOverviewTab extends ConsumerWidget {
  const TontineOverviewTab({required this.data, super.key});

  final TontineDetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TontineCycle? current = data.currentCycle;
    final Beneficiary? currentBeneficiary = current == null
        ? null
        : data.beneficiaryOf(current.id);
    final OrganizationMember? membership = ref
        .watch(currentMembershipProvider)
        .valueOrNull;
    final DrawEligibility? eligibility = data.eligibility;
    final String? blockReason = eligibility == null
        ? null
        : Labels.drawBlockReason(
            context.l10n,
            eligibility,
            locale: context.localeCode,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.xxxl,
      ),
      children: <Widget>[
        KCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.l10n.tontinesPot, style: context.text.labelMedium),
              const SizedBox(height: KSpacing.xs),
              Text(
                MoneyFormatter.format(data.summary.pot, data.tontine.currency),
                style: context.text.displaySmall?.copyWith(
                  color: context.colors.brand,
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                context.l10n.tontinesPotFormula(
                  data.summary.participantCount,
                  MoneyFormatter.format(
                    data.tontine.contributionAmount,
                    data.tontine.currency,
                  ),
                ),
                style: context.text.bodySmall,
              ),
              if (current != null) ...<Widget>[
                KSpacing.gapXl,
                KAmountProgress(
                  label:
                      '${context.l10n.dashboardCollectionProgress} · '
                      '${DateFormatter.periodLabel(current.periodStart, context.localeCode)}',
                  collected: data.summary.collectedCurrentCycle,
                  expected: data.summary.expectedCurrentCycle,
                  currency: data.tontine.currency,
                ),
              ],
            ],
          ),
        ),
        KSpacing.gapLg,
        KStatGrid(
          tiles: <Widget>[
            KStatTile(
              label: context.l10n.tontinesParticipants,
              value: '${data.summary.participantCount}',
              icon: Icons.groups_2_outlined,
            ),
            KStatTile(
              label: context.l10n.tontinesCyclesCompleted,
              value:
                  '${data.summary.completedCycles} / ${data.summary.totalCycles}',
              icon: Icons.check_circle_outline,
              accent: context.colors.success,
            ),
            KStatTile(
              label: context.l10n.drawEligibleParticipants,
              value: '${_eligibleCount()}',
              icon: Icons.casino_outlined,
              accent: context.colors.accent,
            ),
            KStatTile(
              label: context.l10n.tontinesPreviousBeneficiary,
              value: data.summary.previousBeneficiaryName ?? '-',
              icon: Icons.history,
            ),
          ],
        ),
        KSpacing.gapLg,

        if (current != null) ...<Widget>[
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                KSectionHeader(
                  title: context.l10n.dashboardNextDraw,
                  subtitle: DateFormatter.periodLabel(
                    current.periodStart,
                    context.localeCode,
                  ),
                ),
                if (currentBeneficiary != null)
                  KDetailRow(
                    label: context.l10n.dashboardCurrentBeneficiary,
                    value: currentBeneficiary.memberName,
                    icon: Icons.emoji_events_outlined,
                    valueColor: context.colors.accent,
                  )
                else if (data.tontine.allocationMode ==
                    AllocationMode.monthlyDraw) ...<Widget>[
                  Text(
                    context.l10n.drawRemainingToDraw(_eligibleCount()),
                    style: context.text.bodyMedium,
                  ),
                  KSpacing.gapMd,
                  KButton(
                    label: data.eligibility?.allowed ?? false
                        ? context.l10n.drawSpin
                        : context.l10n.drawUnavailable,
                    icon: data.eligibility?.allowed ?? false
                        ? Icons.play_circle_outline
                        : Icons.lock_outline,
                    variant: data.eligibility?.allowed ?? false
                        ? KButtonVariant.primary
                        : KButtonVariant.secondary,
                    onPressed: () => context.push(
                      AppRoutes.tontineDraw(data.tontine.id, current.id),
                    ),
                  ),
                  // Dire pourquoi : un refus muet passe pour une panne.
                  if (blockReason != null) ...<Widget>[
                    KSpacing.gapSm,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          size: KSizes.iconSm,
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: Text(
                            blockReason,
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else
                  Text(
                    context.l10n.allocationFullOrderDesc,
                    style: context.text.bodyMedium,
                  ),
                if (currentBeneficiary != null) ...<Widget>[
                  KSpacing.gapMd,
                  KButton.secondary(
                    label: context.l10n.beneficiaryTitle,
                    icon: Icons.card_giftcard_outlined,
                    onPressed: () => context.push(
                      AppRoutes.tontineBeneficiary(data.tontine.id, current.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
          KSpacing.gapLg,
        ],

        if (membership != null)
          _MyPositionCard(data: data, memberId: membership.id),
      ],
    );
  }

  int _eligibleCount() => data.participants
      .where(
        (TontineParticipant p) =>
            p.isActive && p.isEligibleForDraw && !p.hasReceivedPot,
      )
      .length;
}

/// « Ma position » : rappelle qu'un bénéficiaire continue de cotiser.
class _MyPositionCard extends StatelessWidget {
  const _MyPositionCard({required this.data, required this.memberId});

  final TontineDetailData data;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    TontineParticipant? me;
    for (final TontineParticipant participant in data.participants) {
      if (participant.memberId == memberId) {
        me = participant;
        break;
      }
    }

    if (me == null) {
      return KCard(
        child: Text(
          context.l10n.positionNotParticipant,
          style: context.text.bodyMedium,
        ),
      );
    }

    final int remaining = data.participants
        .where((TontineParticipant p) => p.isActive && !p.hasReceivedPot)
        .length;

    final List<Widget> lines = <Widget>[];
    if (data.tontine.allocationMode.hasPredefinedOrder &&
        me.orderPosition != null) {
      lines.add(
        Text(
          context.l10n.positionOrder(me.orderPosition!),
          style: context.text.titleSmall,
        ),
      );
      final TontineCycle? cycle = _cycleForPosition(me.orderPosition!);
      if (cycle != null) {
        lines.add(
          Text(
            context.l10n.positionEstimatedPeriod(
              DateFormatter.periodLabel(cycle.periodStart, context.localeCode),
            ),
            style: context.text.bodyMedium,
          ),
        );
      }
    }

    if (me.hasReceivedPot) {
      lines.add(
        Text(
          context.l10n.positionReceivedIn(
            me.receivedPeriodStart == null
                ? context.l10n.commonUnknown
                : DateFormatter.periodLabel(
                    me.receivedPeriodStart!,
                    context.localeCode,
                  ),
          ),
          style: context.text.bodyMedium,
        ),
      );
      lines.add(
        Container(
          margin: const EdgeInsets.only(top: KSpacing.md),
          padding: const EdgeInsets.all(KSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.warningSurface,
            borderRadius: KRadius.field,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: KSizes.iconSm,
                color: context.colors.warning,
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.positionKeepContributing,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      lines
        ..add(
          Text(
            context.l10n.positionNotReceived,
            style: context.text.bodyMedium,
          ),
        )
        ..add(
          Text(
            context.l10n.positionRemaining(remaining, data.participants.length),
            style: context.text.bodyMedium,
          ),
        );
    }

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          KSectionHeader(title: context.l10n.positionTitle),
          ...lines,
        ],
      ),
    );
  }

  TontineCycle? _cycleForPosition(int position) {
    for (final TontineCycle cycle in data.cycles) {
      if (cycle.index == position) {
        return cycle;
      }
    }
    return null;
  }
}
