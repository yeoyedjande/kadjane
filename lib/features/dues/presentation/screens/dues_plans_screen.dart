import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/features/dues/presentation/providers/dues_providers.dart';
import 'package:kadjane/features/dues/presentation/widgets/dues_plan_form_sheet.dart';

/// Gestion des cotisations de caisse, par le trésorier.
///
/// C'est lui qui tient la caisse : il ouvre les cotisations, en ajuste le
/// montant, les suspend ou les clôture, sans passer par le back-office.
class DuesPlansScreen extends ConsumerWidget {
  const DuesPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canManage = ref.watch(canProvider(Permission.duesManage));
    final AsyncValue<List<DuesPlan>> plans = ref.watch(duesPlansProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.duesManageTitle)),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => DuesPlanFormSheet.show(context),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.duesPlanNew),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(duesPlansProvider),
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
                    title: context.l10n.duesManageTitle,
                    message: context.l10n.duesPlansEmpty,
                    actionLabel: canManage ? context.l10n.duesPlanNew : null,
                    onAction: canManage
                        ? () => DuesPlanFormSheet.show(context)
                        : null,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.lg,
                // Place pour le bouton flottant, qui ne doit masquer aucune
                // cotisation en fin de liste.
                KSpacing.xxl * 2,
              ),
              itemCount: rows.length,
              separatorBuilder: (_, _) => KSpacing.gapMd,
              itemBuilder: (BuildContext context, int index) =>
                  _PlanCard(plan: rows[index], canManage: canManage),
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.plan, required this.canManage});

  final DuesPlan plan;
  final bool canManage;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _isBusy = false;

  Future<void> _setStatus(DuesPlanStatus status) async {
    final String? organizationId = await ref.read(
      activeOrganizationIdProvider.future,
    );
    if (organizationId == null || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await ref
          .read(duesRepositoryProvider)
          .updatePlan(organizationId, widget.plan.id, status: status);
      refreshOrganizationData(ref);
      if (mounted) {
        context.showMessage(context.l10n.duesPlanUpdated);
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
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _pause() async {
    final bool confirmed = await KConfirmDialog.show(
      context,
      title: context.l10n.duesPlanPauseConfirmTitle,
      message: context.l10n.duesPlanPauseConfirmMessage,
      confirmLabel: context.l10n.duesPlanPause,
      icon: Icons.pause_circle_outline,
    );
    if (confirmed) {
      await _setStatus(DuesPlanStatus.paused);
    }
  }

  Future<void> _close() async {
    final bool confirmed = await KConfirmDialog.show(
      context,
      title: context.l10n.duesPlanCloseConfirmTitle,
      message: context.l10n.duesPlanCloseConfirmMessage,
      confirmLabel: context.l10n.duesPlanClose,
      isDestructive: true,
      icon: Icons.lock_outline,
    );
    if (confirmed) {
      await _setStatus(DuesPlanStatus.closed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DuesPlan plan = widget.plan;

    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: KRadius.card,
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(plan.name, style: context.text.titleMedium),
                    const SizedBox(height: KSpacing.xxs),
                    Text(
                      '${MoneyFormatter.format(plan.amount, Currency.xof)}'
                      ' · ${context.l10n.duesPerMember}'
                      ' · ${Labels.frequency(context.l10n, plan.frequency)}',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              KBadge(
                label: Labels.duesPlanStatus(context.l10n, plan.status),
                tone: StatusTone.duesPlan(context.colors, plan.status),
                compact: true,
              ),
            ],
          ),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            KSpacing.gapSm,
            Text(plan.description!, style: context.text.bodySmall),
          ],
          KSpacing.gapMd,
          Text(
            context.l10n.duesDueDayValue(plan.dueDay),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
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
                  label: context.l10n.duesOutstandingLabel,
                  value: MoneyFormatter.compact(
                    plan.outstandingTotal,
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
          if (!plan.isActive) ...<Widget>[
            KSpacing.gapMd,
            Text(
              plan.isClosed
                  ? context.l10n.duesPlanClosedNotice
                  : context.l10n.duesPlanPausedNotice,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
          if (widget.canManage && !plan.isClosed) ...<Widget>[
            KSpacing.gapMd,
            Divider(color: context.colors.divider, height: 1),
            KSpacing.gapSm,
            Wrap(
              spacing: KSpacing.sm,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () => DuesPlanFormSheet.show(context, plan: plan),
                  icon: const Icon(Icons.edit_outlined, size: KSizes.iconSm),
                  label: Text(context.l10n.commonEdit),
                ),
                TextButton.icon(
                  onPressed: _isBusy
                      ? null
                      : plan.isActive
                      ? _pause
                      : () => _setStatus(DuesPlanStatus.active),
                  icon: Icon(
                    plan.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: KSizes.iconSm,
                  ),
                  label: Text(
                    plan.isActive
                        ? context.l10n.duesPlanPause
                        : context.l10n.duesPlanResume,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isBusy ? null : _close,
                  icon: const Icon(Icons.lock_outline, size: KSizes.iconSm),
                  label: Text(context.l10n.duesPlanClose),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.danger,
                  ),
                ),
              ],
            ),
          ],
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
