import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';

/// Encaissement d'une échéance de caisse.
///
/// Le montant est pré-rempli avec le reste dû mais reste modifiable : un
/// membre règle parfois en plusieurs fois, et le trésorier doit pouvoir
/// enregistrer ce qu'il a réellement reçu.
class RecordDuesPaymentSheet extends ConsumerStatefulWidget {
  const RecordDuesPaymentSheet({required this.entry, super.key});

  final DuesEntry entry;

  /// Ouvre la feuille et renvoie `true` si un règlement a été enregistré.
  static Future<bool> show(BuildContext context, DuesEntry entry) async {
    final bool? recorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: RecordDuesPaymentSheet(entry: entry),
      ),
    );
    return recorded ?? false;
  }

  @override
  ConsumerState<RecordDuesPaymentSheet> createState() =>
      _RecordDuesPaymentSheetState();
}

class _RecordDuesPaymentSheetState
    extends ConsumerState<RecordDuesPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.entry.remainingAmount.toStringAsFixed(0),
  );
  final TextEditingController _reference = TextEditingController();

  PaymentMethod _method = PaymentMethod.cash;
  DateTime _paidAt = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final double? amount = Validators.parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      context.showMessage(context.l10n.duesInvalidAmount, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String reference = _reference.text.trim();
      await ref
          .read(duesRepositoryProvider)
          .recordPayment(
            entryId: widget.entry.id,
            amount: amount,
            method: _method,
            reference: reference.isEmpty ? null : reference,
            paidAt: _paidAt,
          );
      refreshOrganizationData(ref);
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showMessage(context.l10n.duesPaymentRecorded);
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
    final DuesEntry entry = widget.entry;

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
            Text(context.l10n.duesRecordTitle, style: context.text.titleLarge),
            const SizedBox(height: KSpacing.xs),
            Text(
              entry.memberName.isEmpty
                  ? entry.periodLabel
                  : '${entry.memberName} · ${entry.periodLabel}',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              '${context.l10n.duesRemaining} : '
              '${MoneyFormatter.format(entry.remainingAmount, Currency.xof)}',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            KSpacing.gapXl,
            KTextField(
              label: context.l10n.commonAmount,
              controller: _amount,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments_outlined,
            ),
            KSpacing.gapLg,
            KDropdownField<PaymentMethod>(
              label: context.l10n.contributionsPaymentMethod,
              value: _method,
              items: PaymentMethod.values,
              itemLabel: (PaymentMethod method) =>
                  Labels.paymentMethod(context.l10n, method),
              itemIcon: Labels.paymentIcon,
              onChanged: (PaymentMethod? value) =>
                  setState(() => _method = value ?? PaymentMethod.cash),
            ),
            KSpacing.gapLg,
            KDateField(
              label: context.l10n.commonDate,
              value: _paidAt,
              onChanged: (DateTime value) => setState(() => _paidAt = value),
            ),
            KSpacing.gapLg,
            KTextField(
              label:
                  '${context.l10n.commonReference} '
                  '(${context.l10n.commonOptional})',
              controller: _reference,
            ),
            KSpacing.gapXl,
            KButton(
              label: context.l10n.duesRecordTitle,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
