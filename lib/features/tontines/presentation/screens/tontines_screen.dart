import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';
import 'package:kadjane/features/tontines/presentation/widgets/tontine_card.dart';

/// Liste des tontines de l'organisation active.
class TontinesScreen extends ConsumerStatefulWidget {
  const TontinesScreen({super.key});

  @override
  ConsumerState<TontinesScreen> createState() => _TontinesScreenState();
}

class _TontinesScreenState extends ConsumerState<TontinesScreen> {
  TontineStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TontineSummary>> tontines = ref.watch(
      tontineSummariesProvider,
    );
    final bool canCreate = ref.watch(canProvider(Permission.tontineCreate));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tontinesTitle)),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.tontineCreate),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.tontinesCreate),
            )
          : null,
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              children: <Widget>[
                _FilterChip(
                  label: context.l10n.commonAll,
                  selected: _filter == null,
                  onSelected: () => setState(() => _filter = null),
                ),
                ...TontineStatus.values.map(
                  (TontineStatus status) => _FilterChip(
                    label: Labels.tontineStatus(context.l10n, status),
                    selected: _filter == status,
                    onSelected: () => setState(() => _filter = status),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(tontineSummariesProvider),
              child: KAsyncView<List<TontineSummary>>(
                value: tontines,
                onRetry: () => ref.invalidate(tontineSummariesProvider),
                isEmpty: (List<TontineSummary> data) => _apply(data).isEmpty,
                emptyBuilder: (BuildContext context) => KEmptyState(
                  icon: Icons.savings_outlined,
                  message: context.l10n.tontinesEmpty,
                  actionLabel: canCreate ? context.l10n.tontinesCreate : null,
                  onAction: canCreate
                      ? () => context.push(AppRoutes.tontineCreate)
                      : null,
                ),
                builder: (List<TontineSummary> data) {
                  final List<TontineSummary> filtered = _apply(data);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      KSpacing.lg,
                      KSpacing.sm,
                      KSpacing.lg,
                      KSpacing.giant,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => KSpacing.gapMd,
                    itemBuilder: (BuildContext context, int index) =>
                        TontineCard(
                          summary: filtered[index],
                          onTap: () => context.push(
                            AppRoutes.tontineDetail(filtered[index].tontine.id),
                          ),
                        ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TontineSummary> _apply(List<TontineSummary> source) => _filter == null
      ? source
      : source
            .where((TontineSummary s) => s.tontine.status == _filter)
            .toList(growable: false);
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: KSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
