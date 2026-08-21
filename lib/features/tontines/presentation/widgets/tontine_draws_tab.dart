import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Onglet « Tirages » : historique inaltérable des sessions.
class TontineDrawsTab extends ConsumerWidget {
  const TontineDrawsTab({required this.data, super.key});

  final TontineDetailData data;

  Future<void> _invalidate(
    BuildContext context,
    WidgetRef ref,
    DrawSession draw,
  ) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null) {
      return;
    }
    final String? reason = await KReasonDialog.show(
      context,
      title: context.l10n.drawInvalidate,
      message: context.l10n.drawOverrideMessage,
      fieldLabel: context.l10n.drawInvalidateReason,
      confirmLabel: context.l10n.commonConfirm,
    );
    if (reason == null) {
      return;
    }
    try {
      await ref
          .read(drawRepositoryProvider)
          .invalidate(drawId: draw.id, reason: reason, actorMemberId: actor.id);
      ref.invalidate(tontineDetailProvider(data.tontine.id));
      if (context.mounted) {
        context.showMessage(context.l10n.drawStatusInvalidated);
      }
    } on Object catch (error) {
      if (context.mounted) {
        context.showMessage(
          ErrorMapper.message(context.l10n, error),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.draws.isEmpty) {
      return KEmptyState(
        icon: Icons.casino_outlined,
        message: context.l10n.drawHistory,
      );
    }
    final bool canInvalidate = ref.watch(
      canProvider(Permission.drawInvalidate),
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.xxxl,
      ),
      itemCount: data.draws.length,
      separatorBuilder: (_, _) => KSpacing.gapMd,
      itemBuilder: (BuildContext context, int index) {
        final DrawSession draw = data.draws[index];
        return KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      draw.periodLabel,
                      style: context.text.titleSmall,
                    ),
                  ),
                  KBadge(
                    label: Labels.drawStatus(context.l10n, draw.status),
                    tone: StatusTone.draw(context.colors, draw.status),
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),
              KDetailRow(
                label: context.l10n.beneficiaryStepBeneficiary,
                value: draw.winnerName ?? context.l10n.commonUnknown,
                icon: Icons.emoji_events_outlined,
              ),
              KDetailRow(
                label: context.l10n.drawEligibleParticipants,
                value: '${draw.eligibleCount}',
                icon: Icons.groups_2_outlined,
              ),
              KDetailRow(
                label: context.l10n.drawLaunchedBy,
                value: draw.launchedByName ?? context.l10n.commonUnknown,
                icon: Icons.person_outline,
              ),
              KDetailRow(
                label: context.l10n.commonDate,
                value: draw.executedAt == null
                    ? context.l10n.commonNotAvailable
                    : DateFormatter.dateTime(
                        draw.executedAt!,
                        context.localeCode,
                      ),
                icon: Icons.schedule,
              ),
              KDetailRow(
                label: context.l10n.drawReference,
                value: draw.proofReference,
                icon: Icons.verified_outlined,
              ),
              if (draw.overrideUsed)
                Container(
                  margin: const EdgeInsets.only(top: KSpacing.sm),
                  padding: const EdgeInsets.all(KSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.warningSurface,
                    borderRadius: KRadius.field,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.gpp_maybe_outlined,
                        size: KSizes.iconSm,
                        color: context.colors.warning,
                      ),
                      const SizedBox(width: KSpacing.sm),
                      Expanded(
                        child: Text(
                          '${context.l10n.drawOverrideUsed} · '
                          '${draw.overrideReason ?? ''}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (draw.closeReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: KSpacing.sm),
                  child: Text(
                    draw.closeReason!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.danger,
                    ),
                  ),
                ),
              if (canInvalidate && draw.isCompleted) ...<Widget>[
                const Divider(height: KSpacing.xxl),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _invalidate(context, ref, draw),
                    icon: Icon(
                      Icons.block,
                      size: KSizes.iconSm,
                      color: context.colors.danger,
                    ),
                    label: Text(
                      context.l10n.drawInvalidate,
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
