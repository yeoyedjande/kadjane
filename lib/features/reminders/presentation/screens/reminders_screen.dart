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
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';
import 'package:kadjane/features/reminders/presentation/providers/reminder_providers.dart';

/// Centre de relance du trésorier, sur mobile.
///
/// C'est lui qui réclame les cotisations : il doit pouvoir le faire depuis son
/// téléphone, sans ouvrir le back-office. Le message est composé à partir du
/// modèle correspondant au niveau d'escalade de chaque membre.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  final Set<String> _selected = <String>{};
  final Set<ReminderChannel> _channels = <ReminderChannel>{
    ReminderChannel.inApp,
  };
  bool _isSending = false;

  String _keyOf(DunningTarget target) => '${target.cycleId}:${target.memberId}';

  Future<void> _send(List<DunningTarget> targets, Organization organization) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    final List<DunningTarget> chosen = targets
        .where((DunningTarget t) => _selected.contains(_keyOf(t)))
        .toList(growable: false);
    if (actor == null || chosen.isEmpty || _channels.isEmpty) {
      return;
    }

    final bool confirmed = await KConfirmDialog.show(
      context,
      title: context.l10n.remindersConfirmTitle,
      message: context.l10n.remindersConfirmMessage(chosen.length),
      confirmLabel: context.l10n.remindersSend,
      icon: Icons.campaign_outlined,
    );
    if (!confirmed) {
      return;
    }

    setState(() => _isSending = true);
    try {
      // Une campagne par cycle : chaque relance reste rattachée à sa période.
      final Map<String, List<DunningTarget>> byCycle =
          <String, List<DunningTarget>>{};
      for (final DunningTarget target in chosen) {
        byCycle.putIfAbsent(target.cycleId, () => <DunningTarget>[]).add(target);
      }

      int sent = 0;
      for (final MapEntry<String, List<DunningTarget>> entry
          in byCycle.entries) {
        final ReminderCampaignResult result = await ref
            .read(reminderRepositoryProvider)
            .sendCampaign(
              actorMemberId: actor.id,
              draft: ReminderCampaignDraft(
                tontineId: entry.value.first.tontineId,
                cycleId: entry.key,
                channels: _channels.toList(growable: false),
                messages: <String, String>{
                  for (final DunningTarget target in entry.value)
                    target.memberId: _messageFor(target, organization),
                },
              ),
            );
        sent += result.campaign.targetCount;
      }

      _selected.clear();
      ref
        ..invalidate(organizationDunningProvider)
        ..invalidate(reminderCampaignsProvider)
        ..invalidate(myRemindersProvider);
      refreshOrganizationData(ref);
      if (mounted) {
        context.showMessage(context.l10n.remindersSentCount(sent));
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

  String _messageFor(DunningTarget target, Organization organization) =>
      DunningService.render(
        DunningService.defaultTemplate(target.level),
        memberName: target.memberName,
        amount: MoneyFormatter.format(target.amountDue, organization.currency),
        tontineName: target.tontineName,
        periodLabel: DateFormatter.periodLabel(
          target.periodStart,
          context.localeCode,
        ),
        dueDate: DateFormatter.date(target.dueDate, context.localeCode),
        organizationName: organization.name,
        daysLate: target.daysLate,
      );

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DunningTarget>> targets = ref.watch(
      organizationDunningProvider,
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final bool canSend = ref.watch(canProvider(Permission.reminderSend));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.remindersCenter)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(organizationDunningProvider),
        child: KAsyncView<List<DunningTarget>>(
          value: targets,
          onRetry: () => ref.invalidate(organizationDunningProvider),
          isEmpty: (List<DunningTarget> data) => data.isEmpty,
          emptyBuilder: (BuildContext context) =>
              KEmptyState(message: context.l10n.remindersNoTargets),
          builder: (List<DunningTarget> data) => ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.xxxl,
            ),
            children: <Widget>[
              if (canSend) ...<Widget>[
                _ChannelPicker(
                  selected: _channels,
                  onToggle: (ReminderChannel channel) => setState(() {
                    _channels.contains(channel)
                        ? _channels.remove(channel)
                        : _channels.add(channel);
                  }),
                ),
                KSpacing.gapLg,
              ],
              for (final DunningTarget target in data) ...<Widget>[
                _TargetTile(
                  target: target,
                  currency: organization?.currency ?? Currency.xof,
                  selectable: canSend,
                  isSelected: _selected.contains(_keyOf(target)),
                  onToggle: () => setState(() {
                    final String key = _keyOf(target);
                    _selected.contains(key)
                        ? _selected.remove(key)
                        : _selected.add(key);
                  }),
                ),
                KSpacing.gapSm,
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: canSend && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.lg),
                child: FilledButton.icon(
                  onPressed: _isSending || organization == null
                      ? null
                      : () => _send(
                          targets.valueOrNull ?? const <DunningTarget>[],
                          organization,
                        ),
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(
                    context.l10n.remindersConfirmMessage(_selected.length),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ChannelPicker extends StatelessWidget {
  const _ChannelPicker({required this.selected, required this.onToggle});

  final Set<ReminderChannel> selected;
  final ValueChanged<ReminderChannel> onToggle;

  String _label(BuildContext context, ReminderChannel channel) =>
      switch (channel) {
        ReminderChannel.inApp => context.l10n.remindersChannelInApp,
        ReminderChannel.sms => context.l10n.remindersChannelSms,
        ReminderChannel.whatsapp => context.l10n.remindersChannelWhatsapp,
        ReminderChannel.email => context.l10n.remindersChannelEmail,
        ReminderChannel.push => context.l10n.remindersChannelPush,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.l10n.remindersChannel, style: context.text.labelLarge),
        KSpacing.gapSm,
        Wrap(
          spacing: KSpacing.sm,
          runSpacing: KSpacing.sm,
          children: <Widget>[
            for (final ReminderChannel channel in ReminderChannel.values)
              FilterChip(
                label: Text(_label(context, channel)),
                selected: selected.contains(channel),
                onSelected: (_) => onToggle(channel),
              ),
          ],
        ),
      ],
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.target,
    required this.currency,
    required this.selectable,
    required this.isSelected,
    required this.onToggle,
  });

  final DunningTarget target;
  final Currency currency;
  final bool selectable;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final StatusTone tone = switch (target.level) {
      ReminderLevel.upcoming => StatusToneHelper.info(context),
      ReminderLevel.dueToday => StatusToneHelper.warning(context),
      ReminderLevel.late_ => StatusToneHelper.danger(context),
      ReminderLevel.escalated => StatusToneHelper.danger(context),
    };
    final String levelLabel = switch (target.level) {
      ReminderLevel.upcoming => context.l10n.remindersLevelUpcoming,
      ReminderLevel.dueToday => context.l10n.remindersLevelDueToday,
      ReminderLevel.late_ => context.l10n.remindersLevelLate,
      ReminderLevel.escalated => context.l10n.remindersLevelEscalated,
    };

    return InkWell(
      onTap: selectable ? onToggle : null,
      borderRadius: KRadius.card,
      child: Container(
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surfaceMuted,
          borderRadius: KRadius.card,
          border: Border.all(
            color: isSelected ? context.colors.brand : context.colors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            if (selectable)
              Checkbox(value: isSelected, onChanged: (_) => onToggle()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(target.memberName, style: context.text.titleSmall),
                  const SizedBox(height: KSpacing.xxs),
                  Text(
                    target.tontineName,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: KSpacing.xs),
                  KBadge(label: levelLabel, tone: tone, compact: true),
                ],
              ),
            ),
            Text(
              MoneyFormatter.compact(target.amountDue, currency),
              style: context.text.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
