import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/cash_transaction.dart';
import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/transaction_enums.dart';
import 'package:kadjane/domain/repositories/treasury_repository.dart';
import 'package:kadjane/features/treasury/presentation/providers/treasury_providers.dart';

/// Caisse de l'organisation : solde, entrées, sorties.
final AutoDisposeFutureProvider<TreasurySnapshot?> treasuryProvider =
    FutureProvider.autoDispose<TreasurySnapshot?>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return null;
      }
      return ref.watch(treasuryRepositoryProvider).snapshot(organizationId);
    });

class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TreasurySnapshot?> snapshot = ref.watch(treasuryProvider);
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;
    final bool canManage = ref.watch(canProvider(Permission.treasuryManage));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.treasuryTitle)),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => showKSheet<bool>(
                context: context,
                builder: (BuildContext sheetContext) =>
                    const _TransactionSheet(),
              ),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.treasuryAddTransaction),
            )
          : null,
      body: KAsyncView<TreasurySnapshot?>(
        value: snapshot,
        onRetry: () => ref.invalidate(treasuryProvider),
        isEmpty: (TreasurySnapshot? data) => data == null,
        builder: (TreasurySnapshot? data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.giant,
          ),
          children: <Widget>[
            const _TreasurerBoard(),
            KCard(
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.treasuryBalance,
                    style: context.text.labelMedium,
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    MoneyFormatter.format(data!.balance, currency),
                    style: context.text.displaySmall?.copyWith(
                      color: data.balance >= 0
                          ? context.colors.brand
                          : context.colors.danger,
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.gapLg,
            KStatGrid(
              tiles: <Widget>[
                KStatTile(
                  label: context.l10n.treasuryInflows,
                  value: MoneyFormatter.compact(data.inflows, currency),
                  icon: Icons.south_west,
                  accent: context.colors.success,
                ),
                KStatTile(
                  label: context.l10n.treasuryOutflows,
                  value: MoneyFormatter.compact(data.outflows, currency),
                  icon: Icons.north_east,
                  accent: context.colors.danger,
                ),
              ],
            ),
            KSpacing.gapLg,
            KSectionHeader(title: context.l10n.activityTitle),
            if (data.transactions.isEmpty)
              KEmptyState(message: context.l10n.treasuryEmpty)
            else
              ...data.transactions.map(
                (CashTransaction transaction) => Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(KSpacing.sm),
                        decoration: BoxDecoration(
                          color: transaction.type == TransactionType.income
                              ? context.colors.successSurface
                              : context.colors.dangerSurface,
                          borderRadius: BorderRadius.circular(KRadius.sm),
                        ),
                        child: Icon(
                          transaction.type == TransactionType.income
                              ? Icons.south_west
                              : Icons.north_east,
                          size: KSizes.iconSm,
                          color: transaction.type == TransactionType.income
                              ? context.colors.success
                              : context.colors.danger,
                        ),
                      ),
                      const SizedBox(width: KSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              transaction.description ??
                                  transaction.category.code,
                              style: context.text.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DateFormatter.date(
                                transaction.date,
                                context.localeCode,
                              ),
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${transaction.type == TransactionType.income ? '+' : '-'}'
                        '${MoneyFormatter.format(transaction.amount, currency)}',
                        style: context.text.titleSmall?.copyWith(
                          color: transaction.type == TransactionType.income
                              ? context.colors.success
                              : context.colors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Saisie d'une opération de caisse.
class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet();

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  TransactionType _type = TransactionType.income;
  TransactionCategory _category = TransactionCategory.donation;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final double? amount = Validators.parseAmount(_amount.text);
    final String? organizationId = ref
        .read(activeOrganizationIdProvider)
        .valueOrNull;
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (amount == null ||
        amount <= 0 ||
        organizationId == null ||
        actor == null) {
      context.showMessage(context.l10n.commonRequiredField, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(treasuryRepositoryProvider)
          .record(
            organizationId: organizationId,
            actorMemberId: actor.id,
            draft: TransactionDraft(
              type: _type,
              category: _category,
              amount: amount,
              date: _date,
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
            ),
          );
      ref.invalidate(treasuryProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showMessage(context.l10n.treasurySaved);
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.treasuryAddTransaction,
              style: context.text.titleLarge,
            ),
            KSpacing.gapXl,
            KDropdownField<TransactionType>(
              label: context.l10n.treasuryType,
              value: _type,
              items: TransactionType.values,
              itemLabel: (TransactionType type) =>
                  Labels.transactionType(context.l10n, type),
              onChanged: (TransactionType? value) =>
                  setState(() => _type = value ?? TransactionType.income),
            ),
            KSpacing.gapLg,
            KDropdownField<TransactionCategory>(
              label: context.l10n.treasuryCategory,
              value: _category,
              items: TransactionCategory.values,
              itemLabel: (TransactionCategory category) => category.code,
              onChanged: (TransactionCategory? value) => setState(
                () => _category = value ?? TransactionCategory.other,
              ),
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.commonAmount,
              controller: _amount,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments_outlined,
            ),
            KSpacing.gapLg,
            KDateField(
              label: context.l10n.commonDate,
              value: _date,
              onChanged: (DateTime value) => setState(() => _date = value),
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.tontinesDescription,
              controller: _description,
              maxLines: 2,
            ),
            KSpacing.gapXl,
            KButton(
              label: context.l10n.commonSave,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}


/// Bloc du trésorier : ce qu'il détient, et ce qu'il attend encore.
///
/// Le solde des caisses et les cotisations sont deux réalités distinctes :
/// 60 000 attendus ne sont pas 40 000 encaissés, et aucun des deux n'est le
/// solde. Les afficher côte à côte, et non additionnés, est le propos de ce
/// bloc.
///
/// Il s'ajoute au-dessus de l'écran existant : le journal des mouvements, en
/// dessous, ne bouge pas.
class _TreasurerBoard extends ConsumerWidget {
  const _TreasurerBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FinancialDashboard?> dashboard = ref.watch(
      financialDashboardProvider,
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;
    final FinancialDashboard? data = dashboard.valueOrNull;

    // Absent, le bloc disparaît sans bruit : l'écran historique reste complet,
    // et une API plus ancienne n'empêche pas le trésorier de travailler.
    if (data == null) {
      return const SizedBox.shrink();
    }

    final bool canSeeCampaigns = ref.watch(
      canProvider(Permission.contributionView),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        KStatGrid(
          tiles: <Widget>[
            KStatTile(
              label: context.l10n.treasuryExpected,
              value: MoneyFormatter.compact(data.expected, currency),
              icon: Icons.receipt_long_outlined,
            ),
            KStatTile(
              label: context.l10n.treasuryCollected,
              value: MoneyFormatter.compact(data.collected, currency),
              icon: Icons.savings_outlined,
              accent: context.colors.success,
            ),
            KStatTile(
              label: context.l10n.treasuryRemaining,
              value: MoneyFormatter.compact(data.remaining, currency),
              icon: Icons.hourglass_bottom,
            ),
            KStatTile(
              label: context.l10n.treasuryLate,
              value: MoneyFormatter.compact(data.lateAmount, currency),
              icon: Icons.warning_amber_outlined,
              accent: context.colors.danger,
              onTap: canSeeCampaigns
                  ? () => context.push(AppRoutes.unpaid)
                  : null,
            ),
          ],
        ),
        if (data.cashboxes.length > 1) ...<Widget>[
          KSpacing.gapLg,
          KSectionHeader(title: context.l10n.treasuryCashboxes),
          ...data.cashboxes.map(
            (Cashbox box) => Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: KCard(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(box.name, style: context.text.titleSmall),
                    ),
                    Text(
                      MoneyFormatter.format(box.currentBalance, currency),
                      style: context.text.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (canSeeCampaigns) ...<Widget>[
          KSpacing.gapMd,
          Row(
            children: <Widget>[
              KButton.secondary(
                label: context.l10n.campaignsTitle,
                expanded: false,
                size: KButtonSize.small,
                onPressed: () => context.push(AppRoutes.campaigns),
              ),
              const SizedBox(width: KSpacing.sm),
              KButton.ghost(
                label: context.l10n.unpaidTitle,
                onPressed: () => context.push(AppRoutes.unpaid),
              ),
            ],
          ),
        ],
        KSpacing.gapLg,
      ],
    );
  }
}
