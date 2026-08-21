import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
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
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/transaction_enums.dart';
import 'package:kadjane/domain/repositories/treasury_repository.dart';

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
