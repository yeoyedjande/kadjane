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
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/features/treasury/presentation/providers/treasury_providers.dart';

/// Cotisations de l'association : associatives, exceptionnelles, volontaires.
///
/// Les cotisations de tontine ne sont pas ici — elles alimentent la cagnotte
/// d'un cycle et se consultent depuis la tontine. Mélanger les deux
/// laisserait croire que l'argent va au même endroit.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ContributionCampaign>> campaigns = ref.watch(
      campaignsProvider,
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;
    final bool canCreate = ref.watch(
      canProvider(Permission.contributionCreate),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.campaignsTitle)),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final bool? created = await showKSheet<bool>(
                  context: context,
                  builder: (_) => const _CampaignSheet(),
                );
                if (created ?? false) {
                  ref.invalidate(campaignsProvider);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.campaignsCreate),
            )
          : null,
      body: KAsyncView<List<ContributionCampaign>>(
        value: campaigns,
        onRetry: () => ref.invalidate(campaignsProvider),
        isEmpty: (List<ContributionCampaign> data) => data.isEmpty,
        emptyBuilder: (BuildContext context) => KEmptyState(
          icon: Icons.savings_outlined,
          message: context.l10n.campaignsEmpty,
        ),
        builder: (List<ContributionCampaign> data) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.giant,
          ),
          itemCount: data.length,
          separatorBuilder: (_, _) => KSpacing.gapSm,
          itemBuilder: (BuildContext context, int index) =>
              _CampaignCard(campaign: data[index], currency: currency),
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign, required this.currency});

  final ContributionCampaign campaign;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final CampaignSummary? summary = campaign.summary;
    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      onTap: () => context.push(AppRoutes.campaignDetail(campaign.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(campaign.title, style: context.text.titleSmall),
              ),
              _StatusChip(status: campaign.status),
            ],
          ),
          const SizedBox(height: KSpacing.xxs),
          Text(
            campaign.hasExpectedAmount
                ? '${MoneyFormatter.format(campaign.amount, currency)} · '
                      '${_typeLabel(context, campaign.contributionType)}'
                : '${context.l10n.campaignAmountFree} · '
                      '${_typeLabel(context, campaign.contributionType)}',
            style: context.text.bodySmall,
          ),
          if (campaign.dueDate != null) ...<Widget>[
            const SizedBox(height: KSpacing.xxs),
            Text(
              DateFormatter.date(campaign.dueDate!, context.localeCode),
              style: context.text.labelSmall,
            ),
          ],
          if (summary != null) ...<Widget>[
            const SizedBox(height: KSpacing.sm),
            // Trois nombres, jamais confondus : ce qui est attendu, ce qui est
            // encaissé, ce qui manque encore.
            Row(
              children: <Widget>[
                _Figure(
                  label: context.l10n.treasuryExpected,
                  value: MoneyFormatter.compact(summary.expected, currency),
                ),
                _Figure(
                  label: context.l10n.treasuryCollected,
                  value: MoneyFormatter.compact(summary.collected, currency),
                  accent: context.colors.success,
                ),
                _Figure(
                  label: context.l10n.treasuryRemaining,
                  value: MoneyFormatter.compact(summary.remaining, currency),
                ),
              ],
            ),
            if (summary.recoveryRate != null) ...<Widget>[
              const SizedBox(height: KSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(KRadius.sm),
                child: LinearProgressIndicator(
                  value: (summary.recoveryRate! / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: context.colors.surfaceMuted,
                ),
              ),
              const SizedBox(height: KSpacing.xxs),
              Text(
                '${context.l10n.treasuryRecoveryRate} '
                '${summary.recoveryRate!.toStringAsFixed(1)} %',
                style: context.text.labelSmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.text.labelSmall),
        Text(
          value,
          style: context.text.titleSmall?.copyWith(color: accent),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CampaignStatus status;

  @override
  Widget build(BuildContext context) {
    final bool active = status == CampaignStatus.active;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: active
            ? context.colors.successSurface
            : context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        status.code,
        style: context.text.labelSmall?.copyWith(
          color: active ? context.colors.success : context.colors.textSecondary,
        ),
      ),
    );
  }
}

String _typeLabel(BuildContext context, ContributionType type) =>
    switch (type) {
      ContributionType.association => context.l10n.campaignTypeAssociation,
      ContributionType.exceptional => context.l10n.campaignTypeExceptional,
      ContributionType.voluntary => context.l10n.campaignTypeVoluntary,
      ContributionType.tontine => context.l10n.tontinesTitle,
    };

/// Formulaire de création d'une cotisation.
class _CampaignSheet extends ConsumerStatefulWidget {
  const _CampaignSheet();

  @override
  ConsumerState<_CampaignSheet> createState() => _CampaignSheetState();
}

class _CampaignSheetState extends ConsumerState<_CampaignSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  ContributionType _type = ContributionType.association;
  AmountMode _mode = AmountMode.fixed;
  DateTime? _dueDate;
  String? _cashboxId;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Cashbox> boxes =
        ref.watch(cashboxesProvider).valueOrNull ?? const <Cashbox>[];

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.l10n.campaignsCreate, style: context.text.titleMedium),
          KSpacing.gapMd,
          KTextField(
            controller: _title,
            label: context.l10n.campaignTitleField,
            validator: (String? value) => Validators.isBlank(value)
                ? context.l10n.commonRequiredField
                : null,
          ),
          KSpacing.gapSm,
          DropdownButtonFormField<ContributionType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: context.l10n.campaignType),
            items: <ContributionType>[
              ContributionType.association,
              ContributionType.exceptional,
              ContributionType.voluntary,
            ]
                .map(
                  (ContributionType type) => DropdownMenuItem<ContributionType>(
                    value: type,
                    child: Text(_typeLabel(context, type)),
                  ),
                )
                .toList(growable: false),
            onChanged: (ContributionType? value) => setState(() {
              _type = value ?? ContributionType.association;
              // Une collecte volontaire suppose un montant libre : le
              // pré-sélectionner évite un formulaire incohérent.
              if (_type == ContributionType.voluntary) {
                _mode = AmountMode.free;
              }
            }),
          ),
          KSpacing.gapSm,
          DropdownButtonFormField<AmountMode>(
            initialValue: _mode,
            decoration: InputDecoration(
              labelText: context.l10n.campaignAmountMode,
            ),
            items: <DropdownMenuItem<AmountMode>>[
              DropdownMenuItem<AmountMode>(
                value: AmountMode.fixed,
                child: Text(context.l10n.campaignAmountFixed),
              ),
              DropdownMenuItem<AmountMode>(
                value: AmountMode.free,
                child: Text(context.l10n.campaignAmountFree),
              ),
            ],
            onChanged: (AmountMode? value) =>
                setState(() => _mode = value ?? AmountMode.fixed),
          ),
          if (_mode == AmountMode.fixed) ...<Widget>[
            KSpacing.gapSm,
            KTextField(
              controller: _amount,
              label: context.l10n.campaignAmountPerMember,
              keyboardType: TextInputType.number,
              validator: (String? value) =>
                  Validators.isPositiveAmount(value ?? '')
                  ? null
                  : context.l10n.commonRequiredField,
            ),
          ],
          if (boxes.isNotEmpty) ...<Widget>[
            KSpacing.gapSm,
            DropdownButtonFormField<String?>(
              initialValue: _cashboxId,
              decoration: InputDecoration(
                labelText: context.l10n.campaignCashbox,
              ),
              items: <DropdownMenuItem<String?>>[
                for (final Cashbox box in boxes)
                  DropdownMenuItem<String?>(
                    value: box.id,
                    child: Text(box.name),
                  ),
              ],
              onChanged: (String? value) => setState(() => _cashboxId = value),
            ),
          ],
          KSpacing.gapSm,
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.campaignDueDate),
            subtitle: Text(
              _dueDate == null
                  ? '—'
                  : DateFormatter.date(_dueDate!, context.localeCode),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          KSpacing.gapSm,
          // Sans sélection, tous les membres actifs sont concernés : c'est le
          // cas courant, et le détail se règle depuis le back-office.
          Text(context.l10n.campaignAllMembers, style: context.text.bodySmall),
          KSpacing.gapLg,
          KButton(
            label: context.l10n.campaignsCreate,
            isLoading: _saving,
            onPressed: _saving ? null : _submit,
          ),
          KSpacing.gapMd,
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? organizationId = ref
        .read(activeOrganizationIdProvider)
        .valueOrNull;
    if (organizationId == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(cashboxRepositoryProvider)
          .createCampaign(
            organizationId: organizationId,
            title: _title.text.trim(),
            contributionType: _type,
            amountMode: _mode,
            amount: _mode == AmountMode.fixed
                ? Validators.parseAmount(_amount.text) ?? 0
                : 0,
            dueDate: _dueDate,
            cashboxId: _cashboxId,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      context.showMessage(context.l10n.campaignCreated);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      context.showMessage(
        ErrorMapper.message(context.l10n, error),
        isError: true,
      );
    }
  }
}
