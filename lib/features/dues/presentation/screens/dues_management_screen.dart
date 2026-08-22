import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/dues_repository.dart';

/// Encaissement des cotisations de caisse, pour le trésorier.
///
/// Le trésorier détient l'argent : il doit pouvoir pointer et encaisser depuis
/// son téléphone, sans passer par le back-office.
class DuesManagementScreen extends ConsumerStatefulWidget {
  const DuesManagementScreen({super.key});

  @override
  ConsumerState<DuesManagementScreen> createState() =>
      _DuesManagementScreenState();
}

class _DuesManagementScreenState extends ConsumerState<DuesManagementScreen> {
  String? _planId;
  bool _onlyUnpaid = true;
  String? _settlingId;

  Future<({List<DuesPlan> plans, List<DuesEntry> entries})> _load() async {
    final String? organizationId = await ref.read(
      activeOrganizationIdProvider.future,
    );
    if (organizationId == null) {
      return (plans: <DuesPlan>[], entries: <DuesEntry>[]);
    }

    final DuesRepository repository = ref.read(duesRepositoryProvider);
    final List<DuesPlan> plans = await repository.plans(organizationId);
    if (plans.isEmpty) {
      return (plans: plans, entries: <DuesEntry>[]);
    }

    // On garde la cotisation choisie tant qu'elle existe encore.
    final String planId = plans.any((DuesPlan p) => p.id == _planId)
        ? _planId!
        : plans.first.id;
    _planId = planId;
    return (
      plans: plans,
      entries: await repository.entries(organizationId, planId),
    );
  }

  late Future<({List<DuesPlan> plans, List<DuesEntry> entries})> _future =
      _load();

  void _reload() => setState(() => _future = _load());

  Future<void> _settle(DuesEntry entry) async {
    setState(() => _settlingId = entry.id);
    try {
      await ref
          .read(duesRepositoryProvider)
          .recordPayment(
            entryId: entry.id,
            amount: entry.remainingAmount,
            method: PaymentMethod.cash,
          );
      if (mounted) {
        context.showMessage(context.l10n.duesPaymentRecorded);
      }
      _reload();
    } on Object catch (error) {
      if (mounted) {
        context.showMessage(
          ErrorMapper.message(context.l10n, error),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _settlingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.duesCollectTitle)),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child:
            FutureBuilder<({List<DuesPlan> plans, List<DuesEntry> entries})>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return KErrorState(
                    error: snapshot.error!,
                    onRetry: _reload,
                  );
                }

                final ({List<DuesPlan> plans, List<DuesEntry> entries}) data =
                    snapshot.data!;
                if (data.plans.isEmpty) {
                  return _Empty(message: context.l10n.duesNoPlan);
                }

                final List<DuesEntry> rows = _onlyUnpaid
                    ? data.entries
                          .where((DuesEntry e) => !e.isSettled)
                          .toList(growable: false)
                    : data.entries;

                return ListView(
                  padding: const EdgeInsets.all(KSpacing.lg),
                  children: <Widget>[
                    if (data.plans.length > 1) ...<Widget>[
                      _PlanSelector(
                        plans: data.plans,
                        selectedId: _planId,
                        onChanged: (String id) {
                          _planId = id;
                          _reload();
                        },
                      ),
                      KSpacing.gapLg,
                    ],
                    _Summary(
                      plan: data.plans.firstWhere(
                        (DuesPlan p) => p.id == _planId,
                      ),
                    ),
                    KSpacing.gapMd,
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _onlyUnpaid,
                      title: Text(context.l10n.duesOnlyUnpaid),
                      onChanged: (bool value) =>
                          setState(() => _onlyUnpaid = value),
                    ),
                    KSpacing.gapSm,
                    if (rows.isEmpty)
                      _Empty(message: context.l10n.duesNothingToCollect)
                    else
                      for (final DuesEntry entry in rows) ...<Widget>[
                        _EntryRow(
                          entry: entry,
                          isBusy: _settlingId == entry.id,
                          onSettle: () => _settle(entry),
                        ),
                        KSpacing.gapSm,
                      ],
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _PlanSelector extends StatelessWidget {
  const _PlanSelector({
    required this.plans,
    required this.selectedId,
    required this.onChanged,
  });

  final List<DuesPlan> plans;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(labelText: context.l10n.duesTitle),
      items: <DropdownMenuItem<String>>[
        for (final DuesPlan plan in plans)
          DropdownMenuItem<String>(value: plan.id, child: Text(plan.name)),
      ],
      onChanged: (String? value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan});

  final DuesPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.accentContainer,
        borderRadius: KRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(plan.name, style: context.text.titleMedium),
          KSpacing.gapXs,
          Text(
            '${MoneyFormatter.format(plan.amount, Currency.xof)} · ${context.l10n.duesPerMember}',
            style: context.text.bodySmall,
          ),
          KSpacing.gapMd,
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: context.l10n.duesCollected,
                  value: MoneyFormatter.compact(
                    plan.collectedTotal,
                    Currency.xof,
                  ),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: context.l10n.duesUnpaidLabel,
                  value: '${plan.unpaidCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.text.labelSmall),
        const SizedBox(height: KSpacing.xxs),
        Text(value, style: context.text.titleSmall),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isBusy,
    required this.onSettle,
  });

  final DuesEntry entry;
  final bool isBusy;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: KRadius.card,
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.memberName.isEmpty
                      ? context.l10n.membersTitle
                      : entry.memberName,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: KSpacing.xxs),
                Text(
                  '${entry.periodLabel} · ${DateFormatter.date(entry.dueDate)}',
                  style: context.text.bodySmall?.copyWith(
                    color: entry.isLate
                        ? context.colors.danger
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (entry.isSettled)
            Icon(Icons.check_circle, color: context.colors.success)
          else
            TextButton(
              onPressed: isBusy ? null : onSettle,
              child: Text(
                MoneyFormatter.compact(entry.remainingAmount, Currency.xof),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KSpacing.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
