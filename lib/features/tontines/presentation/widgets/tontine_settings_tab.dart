import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Onglet « Paramètres » : réglages et actions d'administration.
class TontineSettingsTab extends ConsumerWidget {
  const TontineSettingsTab({required this.data, super.key});

  final TontineDetailData data;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    TontineStatus status,
  ) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null) {
      return;
    }
    final bool confirmed = await KConfirmDialog.show(
      context,
      title: Labels.tontineStatus(context.l10n, status),
      message: context.l10n.drawConfirmMessage,
      confirmLabel: context.l10n.commonConfirm,
      isDestructive: status == TontineStatus.cancelled,
      icon: Icons.help_outline,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref
          .read(tontineRepositoryProvider)
          .changeStatus(
            tontineId: data.tontine.id,
            status: status,
            actorMemberId: actor.id,
          );
      ref.invalidate(tontineDetailProvider(data.tontine.id));
      refreshOrganizationData(ref);
      if (context.mounted) {
        context.showMessage(context.l10n.orgSaved);
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
    final bool canEdit = ref.watch(canProvider(Permission.tontineEdit));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.xxxl,
      ),
      children: <Widget>[
        KCard(
          child: Column(
            children: <Widget>[
              KDetailRow(
                label: context.l10n.tontinesContributionAmount,
                value: MoneyFormatter.format(
                  data.tontine.contributionAmount,
                  data.tontine.currency,
                ),
              ),
              KDetailRow(
                label: context.l10n.tontinesCurrency,
                value: data.tontine.currency.code,
              ),
              KDetailRow(
                label: context.l10n.tontinesFrequency,
                value: Labels.frequency(context.l10n, data.tontine.frequency),
              ),
              KDetailRow(
                label: context.l10n.allocationMode,
                value: Labels.allocationMode(
                  context.l10n,
                  data.tontine.allocationMode,
                ),
              ),
              KDetailRow(
                label: context.l10n.tontinesStartDate,
                value: DateFormatter.date(
                  data.tontine.startDate,
                  context.localeCode,
                ),
              ),
              KDetailRow(
                label: context.l10n.tontinesDueDay,
                value: '${data.tontine.dueDayOfPeriod}',
              ),
              KDetailRow(
                label: context.l10n.tontinesDrawDay,
                value: '${data.tontine.drawDayOfPeriod}',
              ),
              KDetailRow(
                label: context.l10n.commonStatus,
                value: Labels.tontineStatus(context.l10n, data.tontine.status),
              ),
              // La règle qui gouverne l'ouverture du tirage : sans elle à
              // l'écran, un tirage bloqué reste inexplicable.
              KDetailRow(
                label: context.l10n.orgRequireFullPayment,
                value: data.tontine.requireAllContributionsBeforeDraw
                    ? context.l10n.commonYes
                    : context.l10n.commonNo,
              ),
            ],
          ),
        ),
        if (data.tontine.description != null) ...<Widget>[
          KSpacing.gapLg,
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                KSectionHeader(title: context.l10n.tontinesDescription),
                Text(data.tontine.description!, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
        if (canEdit) ...<Widget>[
          KSpacing.gapXl,
          if (data.tontine.status == TontineStatus.active)
            KButton.secondary(
              label: Labels.tontineStatus(
                context.l10n,
                TontineStatus.suspended,
              ),
              icon: Icons.pause_circle_outline,
              onPressed: () =>
                  _changeStatus(context, ref, TontineStatus.suspended),
            ),
          if (data.tontine.status == TontineStatus.suspended ||
              data.tontine.status == TontineStatus.draft)
            KButton(
              label: Labels.tontineStatus(context.l10n, TontineStatus.active),
              icon: Icons.play_circle_outline,
              onPressed: () =>
                  _changeStatus(context, ref, TontineStatus.active),
            ),
          KSpacing.gapMd,
          if (!data.tontine.status.isFinished)
            KButton.danger(
              label: Labels.tontineStatus(
                context.l10n,
                TontineStatus.cancelled,
              ),
              icon: Icons.cancel_outlined,
              onPressed: () =>
                  _changeStatus(context, ref, TontineStatus.cancelled),
            ),
        ],
      ],
    );
  }
}
