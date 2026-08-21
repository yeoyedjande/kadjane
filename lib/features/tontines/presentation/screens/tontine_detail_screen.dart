import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';
import 'package:kadjane/features/tontines/presentation/widgets/tontine_cycles_tab.dart';
import 'package:kadjane/features/tontines/presentation/widgets/tontine_draws_tab.dart';
import 'package:kadjane/features/tontines/presentation/widgets/tontine_history_tab.dart';
import 'package:kadjane/features/tontines/presentation/widgets/tontine_overview_tab.dart';
import 'package:kadjane/features/tontines/presentation/widgets/tontine_participants_tab.dart';
import 'package:kadjane/features/tontines/presentation/widgets/tontine_settings_tab.dart';

/// Page détail d'une tontine, organisée en onglets.
class TontineDetailScreen extends ConsumerWidget {
  const TontineDetailScreen({required this.tontineId, super.key});

  final String tontineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TontineDetailData> detail = ref.watch(
      tontineDetailProvider(tontineId),
    );

    return KAsyncView<TontineDetailData>(
      value: detail,
      onRetry: () => ref.invalidate(tontineDetailProvider(tontineId)),
      builder: (TontineDetailData data) => DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.tontine.name,
                  style: context.text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  Labels.allocationMode(
                    context.l10n,
                    data.tontine.allocationMode,
                  ),
                  style: context.text.labelSmall,
                ),
              ],
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: KSpacing.lg),
                child: Center(
                  child: KBadge(
                    label: Labels.tontineStatus(
                      context.l10n,
                      data.tontine.status,
                    ),
                    tone: StatusTone.tontine(
                      context.colors,
                      data.tontine.status,
                    ),
                    compact: true,
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(text: context.l10n.tontinesTabOverview),
                Tab(text: context.l10n.tontinesTabContributions),
                Tab(text: context.l10n.tontinesTabDraws),
                Tab(text: context.l10n.tontinesTabParticipants),
                Tab(text: context.l10n.tontinesTabHistory),
                Tab(text: context.l10n.tontinesTabSettings),
              ],
            ),
          ),
          body: TabBarView(
            children: <Widget>[
              TontineOverviewTab(data: data),
              TontineCyclesTab(data: data),
              TontineDrawsTab(data: data),
              TontineParticipantsTab(data: data),
              TontineHistoryTab(data: data),
              TontineSettingsTab(data: data),
            ],
          ),
        ),
      ),
    );
  }
}
