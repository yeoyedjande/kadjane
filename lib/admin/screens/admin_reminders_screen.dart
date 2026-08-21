import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/admin/widgets/admin_page.dart';
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
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';
import 'package:kadjane/features/reminders/presentation/providers/reminder_providers.dart';

/// Centre de relance : qui n'a pas payé, sur quels canaux les prévenir,
/// avec quel message — et l'historique de ce qui a déjà été envoyé.
class AdminRemindersScreen extends ConsumerStatefulWidget {
  const AdminRemindersScreen({super.key});

  @override
  ConsumerState<AdminRemindersScreen> createState() =>
      _AdminRemindersScreenState();
}

class _AdminRemindersScreenState extends ConsumerState<AdminRemindersScreen> {
  final Set<String> _selected = <String>{};
  final Set<ReminderChannel> _channels = <ReminderChannel>{
    ReminderChannel.inApp,
  };
  final TextEditingController _template = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  String _keyOf(DunningTarget target) => '${target.cycleId}:${target.memberId}';

  String _messageFor(
    DunningTarget target,
    Organization organization,
    Currency currency,
  ) {
    final String template = _template.text.trim().isEmpty
        ? DunningService.defaultTemplate(target.level)
        : _template.text.trim();
    return DunningService.render(
      template,
      memberName: target.memberName,
      amount: MoneyFormatter.format(target.amountDue, currency),
      tontineName: target.tontineName,
      periodLabel: DateFormatter.periodLabel(
        target.periodStart,
        context.localeCode,
      ),
      dueDate: DateFormatter.date(target.dueDate, context.localeCode),
      organizationName: organization.name,
      daysLate: target.daysLate,
    );
  }

  Future<void> _send(
    List<DunningTarget> targets,
    Organization organization,
  ) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null || _channels.isEmpty) {
      return;
    }
    final List<DunningTarget> chosen = targets
        .where((DunningTarget t) => _selected.contains(_keyOf(t)))
        .toList(growable: false);
    if (chosen.isEmpty) {
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
        byCycle
            .putIfAbsent(target.cycleId, () => <DunningTarget>[])
            .add(target);
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
                    target.memberId: _messageFor(
                      target,
                      organization,
                      organization.currency,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DunningTarget>> targets = ref.watch(
      organizationDunningProvider,
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final List<ReminderCampaign> campaigns =
        ref.watch(reminderCampaignsProvider).valueOrNull ??
        const <ReminderCampaign>[];
    final bool canSend = ref.watch(canProvider(Permission.reminderSend));
    final Currency currency = organization?.currency ?? Currency.xof;

    return AdminPage(
      title: context.l10n.remindersCenter,
      subtitle: context.l10n.remindersAudited,
      child: KAsyncView<List<DunningTarget>>(
        value: targets,
        onRetry: () => ref.invalidate(organizationDunningProvider),
        builder: (List<DunningTarget> data) {
          if (data.isEmpty) {
            return KEmptyState(
              icon: Icons.verified_outlined,
              title: context.l10n.remindersToRemind,
              message: context.l10n.remindersNoTargets,
            );
          }
          final double totalDue = data
              .where((DunningTarget t) => _selected.contains(_keyOf(t)))
              .fold<double>(
                0,
                (double sum, DunningTarget t) => sum + t.amountDue,
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth > 980;
                  final Widget table = _TargetsTable(
                    targets: data,
                    currency: currency,
                    selected: _selected,
                    keyOf: _keyOf,
                    onToggle: (DunningTarget target, bool value) =>
                        setState(() {
                          if (value) {
                            _selected.add(_keyOf(target));
                          } else {
                            _selected.remove(_keyOf(target));
                          }
                        }),
                    onToggleAll: (bool value) => setState(() {
                      _selected.clear();
                      if (value) {
                        _selected.addAll(data.map(_keyOf));
                      }
                    }),
                  );
                  final Widget composer = _Composer(
                    template: _template,
                    channels: _channels,
                    canSend: canSend,
                    isSending: _isSending,
                    selectedCount: _selected.length,
                    totalDue: totalDue,
                    currency: currency,
                    preview: _selected.isEmpty || organization == null
                        ? null
                        : _messageFor(
                            data.firstWhere(
                              (DunningTarget t) =>
                                  _selected.contains(_keyOf(t)),
                            ),
                            organization,
                            currency,
                          ),
                    onChannelToggle: (ReminderChannel channel) => setState(() {
                      if (_channels.contains(channel)) {
                        _channels.remove(channel);
                      } else {
                        _channels.add(channel);
                      }
                    }),
                    onTemplateChanged: () => setState(() {}),
                    onSend: organization == null
                        ? null
                        : () => _send(data, organization),
                  );

                  if (!wide) {
                    return Column(
                      children: <Widget>[composer, KSpacing.gapLg, table],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: table),
                      const SizedBox(width: KSpacing.lg),
                      SizedBox(width: 380, child: composer),
                    ],
                  );
                },
              ),
              KSpacing.gapXl,
              AdminSection(
                title: context.l10n.remindersHistory,
                padding: EdgeInsets.zero,
                child: AdminTable(
                  emptyLabel: context.l10n.remindersNoHistory,
                  columns: <DataColumn>[
                    DataColumn(label: Text(context.l10n.commonDate)),
                    DataColumn(label: Text(context.l10n.navTontines)),
                    DataColumn(label: Text(context.l10n.contributionsPeriod)),
                    DataColumn(label: Text(context.l10n.remindersChannel)),
                    DataColumn(label: Text(context.l10n.remindersTargets)),
                    DataColumn(label: Text(context.l10n.drawLaunchedBy)),
                  ],
                  rows: campaigns
                      .map(
                        (ReminderCampaign campaign) => DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Text(
                                DateFormatter.dateTime(
                                  campaign.createdAt,
                                  context.localeCode,
                                ),
                              ),
                            ),
                            DataCell(Text(campaign.tontineName)),
                            DataCell(Text(campaign.periodLabel)),
                            DataCell(
                              Wrap(
                                spacing: KSpacing.xs,
                                children: campaign.channels
                                    .map(
                                      (ReminderChannel c) => Icon(
                                        Labels.reminderChannelIcon(c),
                                        size: 15,
                                        color: context.colors.textSecondary,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                            DataCell(Text('${campaign.targetCount}')),
                            DataCell(Text(campaign.createdByName ?? '—')),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TargetsTable extends StatelessWidget {
  const _TargetsTable({
    required this.targets,
    required this.currency,
    required this.selected,
    required this.keyOf,
    required this.onToggle,
    required this.onToggleAll,
  });

  final List<DunningTarget> targets;
  final Currency currency;
  final Set<String> selected;
  final String Function(DunningTarget target) keyOf;
  final void Function(DunningTarget target, bool value) onToggle;
  final ValueChanged<bool> onToggleAll;

  StatusTone _tone(BuildContext context, ReminderLevel level) {
    switch (level) {
      case ReminderLevel.upcoming:
        return StatusTone(context.colors.info, context.colors.infoSurface);
      case ReminderLevel.dueToday:
        return StatusTone(
          context.colors.warning,
          context.colors.warningSurface,
        );
      case ReminderLevel.late_:
      case ReminderLevel.escalated:
        return StatusTone(context.colors.danger, context.colors.dangerSurface);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allSelected =
        targets.isNotEmpty &&
        targets.every((DunningTarget t) => selected.contains(keyOf(t)));

    return AdminSection(
      title: context.l10n.remindersToRemind,
      subtitle: context.l10n.adminSelected(selected.length),
      trailing: TextButton(
        onPressed: () => onToggleAll(!allSelected),
        child: Text(context.l10n.remindersSelectAll),
      ),
      padding: EdgeInsets.zero,
      child: AdminTable(
        columns: <DataColumn>[
          const DataColumn(label: SizedBox(width: 24)),
          DataColumn(label: Text(context.l10n.membersTitle)),
          DataColumn(label: Text(context.l10n.navTontines)),
          DataColumn(label: Text(context.l10n.commonAmount)),
          DataColumn(label: Text(context.l10n.commonStatus)),
          DataColumn(label: Text(context.l10n.remindersHistory)),
        ],
        rows: targets
            .map(
              (DunningTarget target) => DataRow(
                selected: selected.contains(keyOf(target)),
                cells: <DataCell>[
                  DataCell(
                    Checkbox(
                      value: selected.contains(keyOf(target)),
                      onChanged: (bool? value) =>
                          onToggle(target, value ?? false),
                    ),
                  ),
                  DataCell(
                    Text(target.memberName, style: context.text.titleSmall),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(target.tontineName),
                        Text(
                          DateFormatter.periodLabel(
                            target.periodStart,
                            context.localeCode,
                          ),
                          style: context.text.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(MoneyFormatter.format(target.amountDue, currency)),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        KBadge(
                          label: Labels.reminderLevel(
                            context.l10n,
                            target.level,
                          ),
                          tone: _tone(context, target.level),
                          compact: true,
                        ),
                        if (target.daysLate > 0)
                          Text(
                            context.l10n.remindersDaysLate(target.daysLate),
                            style: context.text.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      target.lastReminderAt == null
                          ? '—'
                          : context.l10n.remindersLastSent(
                              DateFormatter.date(
                                target.lastReminderAt!,
                                context.localeCode,
                              ),
                            ),
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.template,
    required this.channels,
    required this.canSend,
    required this.isSending,
    required this.selectedCount,
    required this.totalDue,
    required this.currency,
    required this.preview,
    required this.onChannelToggle,
    required this.onTemplateChanged,
    required this.onSend,
  });

  final TextEditingController template;
  final Set<ReminderChannel> channels;
  final bool canSend;
  final bool isSending;
  final int selectedCount;
  final double totalDue;
  final Currency currency;
  final String? preview;
  final ValueChanged<ReminderChannel> onChannelToggle;
  final VoidCallback onTemplateChanged;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return AdminSection(
      title: context.l10n.remindersSend,
      subtitle: MoneyFormatter.format(totalDue, currency),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.l10n.remindersChannel, style: context.text.labelMedium),
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: ReminderChannel.values
                .map(
                  (ReminderChannel channel) => FilterChip(
                    selected: channels.contains(channel),
                    avatar: Icon(Labels.reminderChannelIcon(channel), size: 16),
                    label: Text(Labels.reminderChannel(context.l10n, channel)),
                    onSelected: (_) => onChannelToggle(channel),
                  ),
                )
                .toList(growable: false),
          ),
          KSpacing.gapLg,
          Text(context.l10n.remindersMessage, style: context.text.labelMedium),
          const SizedBox(height: KSpacing.sm),
          TextField(
            controller: template,
            maxLines: 4,
            onChanged: (_) => onTemplateChanged(),
            decoration: InputDecoration(
              hintText: DunningService.defaultTemplate(ReminderLevel.late_),
              helperText: '{membre} {montant} {tontine} {periode} {echeance}',
              helperMaxLines: 2,
            ),
          ),
          if (preview != null) ...<Widget>[
            KSpacing.gapLg,
            Text(
              context.l10n.remindersPreview,
              style: context.text.labelMedium,
            ),
            const SizedBox(height: KSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: KRadius.field,
              ),
              child: Text(preview!, style: context.text.bodySmall),
            ),
          ],
          KSpacing.gapXl,
          KButton(
            label: context.l10n.remindersSend,
            icon: Icons.send_outlined,
            isLoading: isSending,
            onPressed: !canSend || selectedCount == 0 || channels.isEmpty
                ? null
                : onSend,
          ),
        ],
      ),
    );
  }
}
