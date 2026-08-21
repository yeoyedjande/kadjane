import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/features/members/presentation/providers/member_providers.dart';

/// Assistant de création d'une tontine, étape par étape.
class TontineWizardScreen extends ConsumerStatefulWidget {
  const TontineWizardScreen({super.key});

  @override
  ConsumerState<TontineWizardScreen> createState() =>
      _TontineWizardScreenState();
}

class _TontineWizardScreenState extends ConsumerState<TontineWizardScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  int _step = 0;
  Currency _currency = Currency.xof;
  TontineFrequency _frequency = TontineFrequency.monthly;
  AllocationMode _mode = AllocationMode.monthlyDraw;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month + 1);
  int _dueDay = 5;
  final List<String> _selected = <String>[];
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _amountValue => Validators.parseAmount(_amount.text) ?? 0;

  /// Permet aux widgets d'étape (même bibliothèque) de rafraîchir l'assistant.
  void update(VoidCallback action) => setState(action);

  bool get _canGoNext {
    switch (_step) {
      case 0:
        return _name.text.trim().isNotEmpty && _amountValue > 0;
      case 1:
        return _selected.length >= 2;
      default:
        return true;
    }
  }

  Future<void> _submit() async {
    final String? organizationId = ref
        .read(activeOrganizationIdProvider)
        .valueOrNull;
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (organizationId == null || actor == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(tontineRepositoryProvider)
          .create(
            organizationId: organizationId,
            actorMemberId: actor.id,
            draft: TontineDraft(
              name: _name.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              contributionAmount: _amountValue,
              currency: _currency,
              frequency: _frequency,
              allocationMode: _mode,
              startDate: _startDate,
              dueDayOfPeriod: _dueDay,
              memberIds: List<String>.of(_selected),
              manualOrder: _mode == AllocationMode.manualOrder
                  ? List<String>.of(_selected)
                  : const <String>[],
            ),
          );
      refreshOrganizationData(ref);
      if (mounted) {
        Navigator.of(context).pop();
        context.showMessage(context.l10n.tontinesCreated);
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
    final List<String> titles = <String>[
      context.l10n.tontinesStepInfo,
      context.l10n.tontinesStepParticipants,
      context.l10n.tontinesStepMode,
      context.l10n.tontinesStepSummary,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tontinesCreate),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_step + 1) / titles.length,
            minHeight: 4,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: Row(
            children: <Widget>[
              if (_step > 0) ...<Widget>[
                Expanded(
                  child: KButton.secondary(
                    label: context.l10n.commonBack,
                    onPressed: () => setState(() => _step--),
                  ),
                ),
                const SizedBox(width: KSpacing.md),
              ],
              Expanded(
                flex: 2,
                child: KButton(
                  label: _step == titles.length - 1
                      ? context.l10n.tontinesCreate
                      : context.l10n.commonNext,
                  isLoading: _isSaving,
                  onPressed: !_canGoNext
                      ? null
                      : () {
                          if (_step == titles.length - 1) {
                            _submit();
                          } else {
                            setState(() => _step++);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.lg),
          children: <Widget>[
            Text(
              '${_step + 1}/${titles.length} · ${titles[_step]}',
              style: context.text.labelMedium,
            ),
            KSpacing.gapLg,
            switch (_step) {
              0 => _StepInfo(state: this),
              1 => _StepParticipants(state: this),
              2 => _StepMode(state: this),
              _ => _StepSummary(state: this),
            },
          ],
        ),
      ),
    );
  }
}

class _StepInfo extends StatelessWidget {
  const _StepInfo({required this.state});

  final _TontineWizardScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        KTextField(
          label: context.l10n.tontinesName,
          controller: state._name,
          onChanged: (_) => state.update(() {}),
          validator: (String? value) => Validators.isBlank(value)
              ? context.l10n.commonRequiredField
              : null,
        ),
        KSpacing.gapLg,
        KTextField(
          label:
              '${context.l10n.tontinesDescription} (${context.l10n.commonOptional})',
          controller: state._description,
          maxLines: 3,
        ),
        KSpacing.gapLg,
        KTextField(
          label: context.l10n.tontinesContributionAmount,
          controller: state._amount,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.payments_outlined,
          onChanged: (_) => state.update(() {}),
          validator: (String? value) => Validators.isPositiveAmount(value ?? '')
              ? null
              : context.l10n.commonRequiredField,
        ),
        KSpacing.gapLg,
        KDropdownField<Currency>(
          label: context.l10n.tontinesCurrency,
          value: state._currency,
          items: Currency.values,
          itemLabel: (Currency currency) =>
              '${currency.code} · ${currency.symbol}',
          onChanged: (Currency? value) =>
              state.update(() => state._currency = value ?? Currency.xof),
        ),
        KSpacing.gapLg,
        KDropdownField<TontineFrequency>(
          label: context.l10n.tontinesFrequency,
          value: state._frequency,
          items: TontineFrequency.values,
          itemLabel: (TontineFrequency frequency) =>
              Labels.frequency(context.l10n, frequency),
          onChanged: (TontineFrequency? value) => state.update(
            () => state._frequency = value ?? TontineFrequency.monthly,
          ),
        ),
        KSpacing.gapLg,
        KDateField(
          label: context.l10n.tontinesStartDate,
          value: state._startDate,
          onChanged: (DateTime value) =>
              state.update(() => state._startDate = value),
        ),
        KSpacing.gapLg,
        KDropdownField<int>(
          label: context.l10n.tontinesDueDay,
          value: state._dueDay,
          items: List<int>.generate(28, (int index) => index + 1),
          itemLabel: (int day) => '$day',
          onChanged: (int? value) =>
              state.update(() => state._dueDay = value ?? 5),
        ),
      ],
    );
  }
}

class _StepParticipants extends ConsumerWidget {
  const _StepParticipants({required this.state});

  final _TontineWizardScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PagedResult<OrganizationMember>> members = ref.watch(
      membersProvider,
    );

    return KAsyncView<PagedResult<OrganizationMember>>(
      value: members,
      builder: (PagedResult<OrganizationMember> data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          KCard(
            color: context.scheme.primaryContainer,
            borderColor: context.scheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.tontinesParticipantsCount(
                    state._selected.length,
                  ),
                  style: context.text.titleMedium?.copyWith(
                    color: context.scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  context.l10n.tontinesPotFormula(
                    state._selected.length,
                    MoneyFormatter.format(state._amountValue, state._currency),
                  ),
                  style: context.text.bodySmall?.copyWith(
                    color: context.scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  '${context.l10n.tontinesEstimatedPot} : '
                  '${MoneyFormatter.format(state._amountValue * state._selected.length, state._currency)}',
                  style: context.text.titleSmall?.copyWith(
                    color: context.scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          KSpacing.gapLg,
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.tontinesSelectParticipants,
                  style: context.text.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => state.update(() {
                  if (state._selected.length == data.items.length) {
                    state._selected.clear();
                  } else {
                    state._selected
                      ..clear()
                      ..addAll(data.items.map((OrganizationMember m) => m.id));
                  }
                }),
                child: Text(context.l10n.commonAll),
              ),
            ],
          ),
          ...data.items.map(
            (OrganizationMember member) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: state._selected.contains(member.id),
              onChanged: (bool? checked) => state.update(() {
                if (checked ?? false) {
                  state._selected.add(member.id);
                } else {
                  state._selected.remove(member.id);
                }
              }),
              title: Text(member.fullName, style: context.text.titleSmall),
              subtitle: Text(
                Labels.role(context.l10n, member.role),
                style: context.text.bodySmall,
              ),
              secondary: KAvatar(
                name: member.fullName,
                imageUrl: member.user.avatarUrl,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepMode extends StatelessWidget {
  const _StepMode({required this.state});

  final _TontineWizardScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: AllocationMode.values
          .map(
            (AllocationMode mode) => Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.md),
              child: KCard(
                onTap: () => state.update(() => state._mode = mode),
                borderColor: state._mode == mode
                    ? context.scheme.primary
                    : context.colors.divider,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      state._mode == mode
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: state._mode == mode
                          ? context.scheme.primary
                          : context.colors.textTertiary,
                    ),
                    const SizedBox(width: KSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            Labels.allocationMode(context.l10n, mode),
                            style: context.text.titleSmall,
                          ),
                          const SizedBox(height: KSpacing.xs),
                          Text(
                            Labels.allocationModeDescription(
                              context.l10n,
                              mode,
                            ),
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _StepSummary extends ConsumerWidget {
  const _StepSummary({required this.state});

  final _TontineWizardScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    return KCard(
      child: Column(
        children: <Widget>[
          KDetailRow(
            label: context.l10n.tontinesName,
            value: state._name.text.trim(),
          ),
          KDetailRow(
            label: context.l10n.orgName,
            value: organization?.name ?? '-',
          ),
          KDetailRow(
            label: context.l10n.tontinesContributionAmount,
            value: MoneyFormatter.format(state._amountValue, state._currency),
          ),
          KDetailRow(
            label: context.l10n.tontinesFrequency,
            value: Labels.frequency(context.l10n, state._frequency),
          ),
          KDetailRow(
            label: context.l10n.tontinesStartDate,
            value: DateFormatter.date(state._startDate, context.localeCode),
          ),
          KDetailRow(
            label: context.l10n.tontinesDueDay,
            value: '${state._dueDay}',
          ),
          KDetailRow(
            label: context.l10n.tontinesParticipants,
            value: '${state._selected.length}',
          ),
          KDetailRow(
            label: context.l10n.allocationMode,
            value: Labels.allocationMode(context.l10n, state._mode),
          ),
          const Divider(height: KSpacing.xxl),
          KDetailRow(
            label: context.l10n.tontinesEstimatedPot,
            value: MoneyFormatter.format(
              state._amountValue * state._selected.length,
              state._currency,
            ),
            valueColor: context.colors.brand,
          ),
        ],
      ),
    );
  }
}
