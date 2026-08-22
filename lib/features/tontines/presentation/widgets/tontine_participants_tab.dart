import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Onglet « Participants ».
///
/// Rappel métier : un bénéficiaire déjà servi reste participant actif ; seule
/// son éligibilité au tirage devient fausse.
class TontineParticipantsTab extends StatelessWidget {
  const TontineParticipantsTab({required this.data, super.key});

  final TontineDetailData data;

  @override
  Widget build(BuildContext context) {
    if (data.participants.isEmpty) {
      return KEmptyState(message: context.l10n.membersEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.lg,
        KSpacing.xxxl,
      ),
      itemCount: data.participants.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final TontineParticipant participant = data.participants[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () =>
              context.push(AppRoutes.memberDetail(participant.memberId)),
          leading: KAvatar(
            name: participant.displayName,
            imageUrl: participant.avatarUrl,
          ),
          title: Row(
            children: <Widget>[
              if (participant.orderPosition != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.sm,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceMuted,
                    borderRadius: KRadius.badge,
                  ),
                  child: Text(
                    '${participant.orderPosition}',
                    style: context.text.labelSmall,
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
              ],
              Expanded(
                child: Text(
                  participant.displayName,
                  style: context.text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            participant.hasReceivedPot &&
                    participant.receivedPeriodStart != null
                ? context.l10n.positionReceivedIn(
                    DateFormatter.periodLabel(
                      participant.receivedPeriodStart!,
                      context.localeCode,
                    ),
                  )
                : context.l10n.positionNotReceived,
            style: context.text.bodySmall,
          ),
          trailing: KBadge(
            label: participant.isEligibleForDraw
                ? context.l10n.drawEligibleParticipants
                : context.l10n.beneficiaryStepBeneficiary,
            tone: participant.isEligibleForDraw
                ? StatusToneHelper.info(context)
                : StatusToneHelper.success(context),
            compact: true,
          ),
        );
      },
    );
  }
}
