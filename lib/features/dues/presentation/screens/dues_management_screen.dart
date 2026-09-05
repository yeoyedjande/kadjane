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
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/features/dues/presentation/providers/dues_providers.dart';
import 'package:kadjane/features/dues/presentation/widgets/dues_plan_form_sheet.dart';
import 'package:kadjane/features/dues/presentation/widgets/record_dues_payment_sheet.dart';

/// Encaissement des cotisations de caisse, pour le trésorier.
///
/// Le trésorier détient l'argent : il doit pouvoir pointer et encaisser depuis
/// son téléphone. La définition des cotisations elle-même se fait sur l'écran
/// de gestion, accessible depuis la barre du haut.
class DuesManagementScreen extends ConsumerStatefulWidget {
  const DuesManagementScreen({super.key});

  @override
  ConsumerState<DuesManagementScreen> createState() =>
      _DuesManagementScreenState();
}

class _DuesManagementScreenState extends ConsumerState<DuesManagementScreen> {
  String? _planId;
  int? _period;
  bool _onlyUnpaid = true;

  @override
  Widget build(BuildContext context) {
    final bool canManage = ref.watch(canProvider(Permission.duesManage));
    final AsyncValue<List<DuesPlan>> plans = ref.watch(duesPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.duesCollectTitle),
        actions: <Widget>[
          if (canManage)
            IconButton(
              tooltip: context.l10n.duesManageTitle,
              icon: const Icon(Icons.tune_outlined),
              onPressed: () => context.push(AppRoutes.duesPlans),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshDues(ref),
        child: plans.when(
          loading: () => const KLoadingView(),
          error: (Object error, _) => KErrorState(
            error: error,
            onRetry: () => ref.invalidate(duesPlansProvider),
          ),
          data: (List<DuesPlan> rows) {
            if (rows.isEmpty) {
              return ListView(
                children: <Widget>[
                  const SizedBox(height: KSpacing.xxl),
                  KEmptyState(
                    icon: Icons.savings_outlined,
                    title: context.l10n.duesTitle,
                    message: canManage
                        ? context.l10n.duesPlansEmpty
                        : context.l10n.duesNoPlan,
                    actionLabel: canManage ? context.l10n.duesPlanNew : null,
                    onAction: canManage
                        ? () => DuesPlanFormSheet.show(context)
                        : null,
                  ),
                ],
              );
            }

            // La cotisation choisie survit à un rafraîchissement tant qu'elle
            // existe encore ; sinon on retombe sur la première.
            final DuesPlan plan = rows.firstWhere(
              (DuesPlan p) => p.id == _planId,
              orElse: () => rows.first,
            );
            if (plan.id != _planId) {
              _planId = plan.id;
              _period = null;
            }

            return _Collection(
              plans: rows,
              plan: plan,
              period: _period,
              onlyUnpaid: _onlyUnpaid,
              onPlanChanged: (String id) => setState(() {
                _planId = id;
                _period = null;
              }),
              onPeriodChanged: (int? period) =>
                  setState(() => _period = period),
              onUnpaidChanged: (bool value) =>
                  setState(() => _onlyUnpaid = value),
            );
          },
        ),
      ),
    );
  }
}

class _Collection extends ConsumerWidget {
  const _Collection({
    required this.plans,
    required this.plan,
    required this.period,
    required this.onlyUnpaid,
    required this.onPlanChanged,
    required this.onPeriodChanged,
    required this.onUnpaidChanged,
  });

  final List<DuesPlan> plans;
  final DuesPlan plan;
  final int? period;
  final bool onlyUnpaid;
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<int?> onPeriodChanged;
  final ValueChanged<bool> onUnpaidChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canRecord = ref.watch(canProvider(Permission.duesRecord));
    // Les échéances sont toujours chargées en entier : le filtre par période
    // se fait à l'affichage, ce qui évite un aller-retour à chaque changement.
    final AsyncValue<List<DuesEntry>> entries = ref.watch(
      duesEntriesProvider(DuesEntriesQuery(plan.id)),
    );

    return entries.when(
      loading: () => const KLoadingView(),
      error: (Object error, _) => KErrorState(
        error: error,
        onRetry: () => ref.invalidate(duesEntriesProvider),
      ),
      data: (List<DuesEntry> all) {
        final List<DuesEntry> rows = all
            .where(
              (DuesEntry e) =>
                  (period == null || e.sequenceNumber == period) &&
                  (!onlyUnpaid || !e.isSettled),
            )
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.all(KSpacing.lg),
          children: <Widget>[
            if (plans.length > 1) ...<Widget>[
              KDropdownField<String>(
                label: context.l10n.duesTitle,
                value: plan.id,
                items: plans.map((DuesPlan p) => p.id).toList(growable: false),
                itemLabel: (String id) =>
                    plans.firstWhere((DuesPlan p) => p.id == id).name,
                onChanged: (String? value) {
                  if (value != null) {
                    onPlanChanged(value);
                  }
                },
              ),
              KSpacing.gapLg,
            ],
            _Summary(plan: plan, rows: rows),
            KSpacing.gapMd,
            _PeriodSelector(
              entries: all,
              period: period,
              onChanged: onPeriodChanged,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: onlyUnpaid,
              title: Text(context.l10n.duesOnlyUnpaid),
              onChanged: onUnpaidChanged,
            ),
            KSpacing.gapSm,
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Text(
                  context.l10n.duesNothingToCollect,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              )
            else
              for (final DuesEntry entry in rows) ...<Widget>[
                _EntryRow(entry: entry, canRecord: canRecord),
                KSpacing.gapSm,
              ],
          ],
        );
      },
    );
  }
}

/// Filtre par période, construit à partir des échéances déjà chargées.
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.entries,
    required this.period,
    required this.onChanged,
  });

  final List<DuesEntry> entries;
  final int? period;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final Map<int, String> periods = <int, String>{
      for (final DuesEntry entry in entries)
        entry.sequenceNumber: entry.periodLabel,
    };
    if (periods.length < 2) {
      return const SizedBox.shrink();
    }
    final List<int> sequences = periods.keys.toList()
      ..sort((int a, int b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: KDropdownField<int>(
        label: context.l10n.duesPeriodFilter,
        // 0 tient lieu de « toutes » : le sélecteur n'accepte pas de valeur
        // nulle dans sa liste.
        value: period ?? 0,
        items: <int>[0, ...sequences],
        itemLabel: (int value) =>
            value == 0 ? context.l10n.duesAllPeriods : periods[value]!,
        onChanged: (int? value) =>
            onChanged(value == null || value == 0 ? null : value),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.rows});

  final DuesPlan plan;
  final List<DuesEntry> rows;

  @override
  Widget build(BuildContext context) {
    // Les totaux suivent le filtre affiché : le trésorier lit ce qu'il voit.
    double expected = 0;
    double collected = 0;
    int unpaid = 0;
    for (final DuesEntry entry in rows) {
      expected += entry.expectedAmount;
      collected += entry.paidAmount;
      if (!entry.isSettled) {
        unpaid++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.accentContainer,
        borderRadius: KRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(plan.name, style: context.text.titleMedium),
              ),
              KBadge(
                label: Labels.duesPlanStatus(context.l10n, plan.status),
                tone: StatusTone.duesPlan(context.colors, plan.status),
                compact: true,
              ),
            ],
          ),
          KSpacing.gapXs,
          Text(
            '${MoneyFormatter.format(plan.amount, Currency.xof)} · '
            '${context.l10n.duesPerMember}',
            style: context.text.bodySmall,
          ),
          KSpacing.gapMd,
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: context.l10n.duesExpected,
                  value: MoneyFormatter.compact(expected, Currency.xof),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: context.l10n.duesCollected,
                  value: MoneyFormatter.compact(collected, Currency.xof),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: context.l10n.duesUnpaidLabel,
                  value: '$unpaid',
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
  const _EntryRow({required this.entry, required this.canRecord});

  final DuesEntry entry;
  final bool canRecord;

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
                  '${entry.periodLabel} · '
                  '${context.l10n.duesDueOn(DateFormatter.date(entry.dueDate))}',
                  style: context.text.bodySmall?.copyWith(
                    color: entry.isLate
                        ? context.colors.danger
                        : context.colors.textSecondary,
                  ),
                ),
                if (entry.paidAmount > 0 && !entry.isSettled) ...<Widget>[
                  const SizedBox(height: KSpacing.xxs),
                  Text(
                    '${context.l10n.duesRemaining} : '
                    '${MoneyFormatter.format(entry.remainingAmount, Currency.xof)}',
                    style: context.text.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          if (entry.isSettled)
            Icon(Icons.check_circle, color: context.colors.success)
          else if (canRecord)
            TextButton(
              onPressed: () => RecordDuesPaymentSheet.show(context, entry),
              child: Text(
                MoneyFormatter.compact(entry.remainingAmount, Currency.xof),
              ),
            )
          else
            Text(
              MoneyFormatter.compact(entry.remainingAmount, Currency.xof),
              style: context.text.titleSmall,
            ),
        ],
      ),
    );
  }
}
