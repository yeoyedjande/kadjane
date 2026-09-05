import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';

/// Création et modification d'une cotisation de caisse, par le trésorier.
///
/// Un même formulaire pour les deux gestes : seuls la périodicité et la date
/// de début se figent une fois la cotisation ouverte, car les échéances déjà
/// engendrées en dépendent.
class DuesPlanFormSheet extends ConsumerStatefulWidget {
  const DuesPlanFormSheet({super.key, this.plan});

  /// `null` pour une création.
  final DuesPlan? plan;

  /// Ouvre la feuille et renvoie `true` si une cotisation a été enregistrée.
  static Future<bool> show(BuildContext context, {DuesPlan? plan}) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DuesPlanFormSheet(plan: plan),
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<DuesPlanFormSheet> createState() => _DuesPlanFormSheetState();
}

class _DuesPlanFormSheetState extends ConsumerState<DuesPlanFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.plan?.name ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.plan == null ? '' : widget.plan!.amount.toStringAsFixed(0),
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.plan?.description ?? '',
  );
  late final TextEditingController _customDays = TextEditingController(
    text: widget.plan?.customPeriodDays?.toString() ?? '30',
  );

  late TontineFrequency _frequency =
      widget.plan?.frequency ?? TontineFrequency.monthly;
  late int _dueDay = widget.plan?.dueDay ?? 5;
  late DateTime _startDate = widget.plan?.startDate ?? DateTime.now();

  bool _isSaving = false;

  bool get _isEditing => widget.plan != null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _description.dispose();
    _customDays.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    final double? amount = Validators.parseAmount(_amount.text);
    if (name.isEmpty || amount == null || amount <= 0) {
      context.showMessage(context.l10n.commonRequiredField, isError: true);
      return;
    }

    final String? organizationId = await ref.read(
      activeOrganizationIdProvider.future,
    );
    if (organizationId == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String description = _description.text.trim();
      if (_isEditing) {
        await ref
            .read(duesRepositoryProvider)
            .updatePlan(
              organizationId,
              widget.plan!.id,
              name: name,
              amount: amount,
              description: description,
              dueDay: _dueDay,
            );
      } else {
        await ref
            .read(duesRepositoryProvider)
            .createPlan(
              organizationId,
              DuesPlanDraft(
                name: name,
                amount: amount,
                frequency: _frequency,
                dueDay: _dueDay,
                customPeriodDays: _frequency == TontineFrequency.custom
                    ? int.tryParse(_customDays.text.trim())
                    : null,
                startDate: _startDate,
                description: description.isEmpty ? null : description,
              ),
            );
      }
      refreshOrganizationData(ref);
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showMessage(
          _isEditing
              ? context.l10n.duesPlanUpdated
              : context.l10n.duesPlanCreated(name),
        );
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
              _isEditing
                  ? context.l10n.duesPlanEditTitle
                  : context.l10n.duesPlanNew,
              style: context.text.titleLarge,
            ),
            KSpacing.gapXl,
            KTextField(
              label: context.l10n.duesPlanName,
              controller: _name,
              hint: context.l10n.duesPlanNameHint,
              prefixIcon: Icons.savings_outlined,
              textInputAction: TextInputAction.next,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.duesPlanAmount,
              controller: _amount,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments_outlined,
              helper: _isEditing
                  ? context.l10n.duesPlanAmountFutureOnly
                  : context.l10n.duesPlanAmountHint,
            ),
            KSpacing.gapLg,
            // Périodicité et date de début se figent après l'ouverture : les
            // échéances déjà engendrées en découlent.
            if (_isEditing)
              _LockedRow(
                label: context.l10n.duesPlanFrequency,
                value: Labels.frequency(context.l10n, widget.plan!.frequency),
              )
            else ...<Widget>[
              KDropdownField<TontineFrequency>(
                label: context.l10n.duesPlanFrequency,
                value: _frequency,
                items: TontineFrequency.values,
                itemLabel: (TontineFrequency f) =>
                    Labels.frequency(context.l10n, f),
                onChanged: (TontineFrequency? value) => setState(
                  () => _frequency = value ?? TontineFrequency.monthly,
                ),
              ),
              if (_frequency == TontineFrequency.custom) ...<Widget>[
                KSpacing.gapLg,
                KTextField(
                  label: context.l10n.duesPlanCustomDays,
                  controller: _customDays,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.timelapse_outlined,
                ),
              ],
            ],
            KSpacing.gapLg,
            KDropdownField<int>(
              label: context.l10n.duesPlanDueDay,
              value: _dueDay,
              items: List<int>.generate(31, (int index) => index + 1),
              itemLabel: (int day) => '$day',
              onChanged: (int? value) => setState(() => _dueDay = value ?? 5),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              context.l10n.duesPlanDueDayHint,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            KSpacing.gapLg,
            if (_isEditing)
              _LockedRow(
                label: context.l10n.duesPlanStartDate,
                value: context.l10n.duesPlanStartDateLocked,
              )
            else
              KDateField(
                label: context.l10n.duesPlanStartDate,
                value: _startDate,
                onChanged: (DateTime value) =>
                    setState(() => _startDate = value),
              ),
            KSpacing.gapLg,
            KTextField(
              label:
                  '${context.l10n.duesPlanDescription} '
                  '(${context.l10n.commonOptional})',
              controller: _description,
              maxLines: 2,
            ),
            KSpacing.gapXl,
            KButton(
              label: context.l10n.commonSave,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Champ non modifiable, affiché pour expliquer ce qui est figé.
class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.text.labelMedium),
        const SizedBox(height: KSpacing.xs),
        Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              size: KSizes.iconSm,
              color: context.colors.textTertiary,
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                value,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
