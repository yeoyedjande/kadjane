import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';
import 'package:kadjane/features/reminders/presentation/providers/reminder_providers.dart';

/// Relance en un geste depuis le mobile : tous les impayés d'une période sont
/// notifiés avec un message adapté à leur niveau de retard.
///
/// La console d'administration offre la version complète (choix des
/// destinataires, des canaux et du message).
class QuickRemindButton extends ConsumerStatefulWidget {
  const QuickRemindButton({
    required this.tontineId,
    required this.cycleId,
    super.key,
  });

  final String tontineId;
  final String cycleId;

  @override
  ConsumerState<QuickRemindButton> createState() => _QuickRemindButtonState();
}

class _QuickRemindButtonState extends ConsumerState<QuickRemindButton> {
  bool _isSending = false;

  Future<void> _send(List<DunningTarget> targets) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    final Organization? organization = ref
        .read(activeOrganizationProvider)
        .valueOrNull;
    if (actor == null || organization == null || targets.isEmpty) {
      return;
    }
    // Capturé avant la boîte de dialogue : plus de contexte après l'attente.
    final String locale = context.localeCode;

    final bool confirmed = await KConfirmDialog.show(
      context,
      title: context.l10n.remindersConfirmTitle,
      message: context.l10n.remindersConfirmMessage(targets.length),
      confirmLabel: context.l10n.remindersSend,
      icon: Icons.campaign_outlined,
    );
    if (!confirmed) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final ReminderCampaignResult result = await ref
          .read(reminderRepositoryProvider)
          .sendCampaign(
            actorMemberId: actor.id,
            draft: ReminderCampaignDraft(
              tontineId: widget.tontineId,
              cycleId: widget.cycleId,
              channels: const <ReminderChannel>[ReminderChannel.inApp],
              messages: <String, String>{
                for (final DunningTarget target in targets)
                  target.memberId: DunningService.render(
                    DunningService.defaultTemplate(target.level),
                    memberName: target.memberName,
                    amount: MoneyFormatter.format(
                      target.amountDue,
                      organization.currency,
                    ),
                    tontineName: target.tontineName,
                    periodLabel: DateFormatter.periodLabel(
                      target.periodStart,
                      locale,
                    ),
                    dueDate: DateFormatter.date(target.dueDate, locale),
                    organizationName: organization.name,
                    daysLate: target.daysLate,
                  ),
              },
            ),
          );
      ref.invalidate(
        cycleDunningProvider(
          CycleRef(tontineId: widget.tontineId, cycleId: widget.cycleId),
        ),
      );
      refreshOrganizationData(ref);
      if (mounted) {
        context.showMessage(
          context.l10n.remindersSentCount(result.campaign.targetCount),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        context.showMessage(
          ErrorMapper.message(context.l10n, error),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canProvider(Permission.reminderSend))) {
      return const SizedBox.shrink();
    }
    final List<DunningTarget> targets =
        ref
            .watch(
              cycleDunningProvider(
                CycleRef(tontineId: widget.tontineId, cycleId: widget.cycleId),
              ),
            )
            .valueOrNull ??
        const <DunningTarget>[];

    if (targets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: KSpacing.sm),
      child: TextButton.icon(
        onPressed: _isSending ? null : () => _send(targets),
        icon: _isSending
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.campaign_outlined, size: KSizes.iconSm),
        label: Text('${context.l10n.remindersSendShort} (${targets.length})'),
      ),
    );
  }
}
