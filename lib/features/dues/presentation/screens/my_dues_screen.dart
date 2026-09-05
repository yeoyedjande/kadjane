import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/features/dues/presentation/providers/dues_providers.dart';

/// Ce que le membre doit à la caisse de son association.
///
/// Lecture seule pour lui : c'est le trésorier qui encaisse et enregistre.
/// Ce dernier accède depuis cette page à l'encaissement et, s'il en a le
/// droit, à la définition des cotisations.
class MyDuesScreen extends ConsumerWidget {
  const MyDuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canCollect = ref.watch(canProvider(Permission.duesRecord));
    final bool canManage = ref.watch(canProvider(Permission.duesManage));
    final AsyncValue<List<DuesEntry>> dues = ref.watch(myDuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.duesTitle),
        actions: <Widget>[
          if (canManage)
            IconButton(
              tooltip: context.l10n.duesManageTitle,
              icon: const Icon(Icons.tune_outlined),
              onPressed: () => context.push(AppRoutes.duesPlans),
            ),
          if (canCollect)
            IconButton(
              tooltip: context.l10n.duesCollectTitle,
              icon: const Icon(Icons.point_of_sale_outlined),
              onPressed: () => context.push(AppRoutes.duesCollect),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myDuesProvider),
        child: dues.when(
          loading: () => const KLoadingView(),
          error: (Object error, _) => KErrorState(
            error: error,
            onRetry: () => ref.invalidate(myDuesProvider),
          ),
          data: (List<DuesEntry> entries) {
            if (entries.isEmpty) {
              return _Message(text: context.l10n.duesAllSettled);
            }

            final double total = entries.fold<double>(
              0,
              (double sum, DuesEntry e) => sum + e.remainingAmount,
            );

            return ListView.separated(
              padding: const EdgeInsets.all(KSpacing.lg),
              itemCount: entries.length + 1,
              separatorBuilder: (_, _) => KSpacing.gapMd,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return _TotalCard(amount: total, count: entries.length);
                }
                return _EntryTile(entry: entries[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.amount, required this.count});

  final double amount;
  final int count;

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
          Text(context.l10n.duesTotalDue, style: context.text.bodyMedium),
          KSpacing.gapXs,
          Text(
            MoneyFormatter.format(amount, Currency.xof),
            style: context.text.headlineMedium,
          ),
          KSpacing.gapXs,
          Text(
            context.l10n.duesUnpaidCount(count),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final DuesEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color accent = entry.isLate
        ? context.colors.danger
        : context.colors.textSecondary;

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
                  entry.planName.isEmpty
                      ? context.l10n.duesTitle
                      : entry.planName,
                  style: context.text.titleSmall,
                ),
                KSpacing.gapXs,
                Text(
                  '${entry.periodLabel} · ${context.l10n.duesDueOn(DateFormatter.date(entry.dueDate))}',
                  style: context.text.bodySmall?.copyWith(color: accent),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.format(entry.remainingAmount, Currency.xof),
            style: context.text.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // `ListView` et non `Center` : le geste de rafraîchissement doit rester
    // possible même quand il n'y a rien à afficher.
    return ListView(
      padding: const EdgeInsets.all(KSpacing.xl),
      children: <Widget>[
        Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
