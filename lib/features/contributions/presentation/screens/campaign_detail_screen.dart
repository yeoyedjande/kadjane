import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
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
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/features/treasury/presentation/providers/treasury_providers.dart';

/// Fiche d'une cotisation : agrégats, puis suivi de chaque membre.
///
/// Le trésorier y encaisse. Une seule saisie suffit : le serveur met à jour
/// le suivi, le reste, le statut, la caisse, l'audit et la notification.
class CampaignDetailScreen extends ConsumerWidget {
  const CampaignDetailScreen({required this.campaignId, super.key});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ContributionCampaign> campaign = ref.watch(
      campaignProvider(campaignId),
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.campaignsTitle)),
      body: KAsyncView<ContributionCampaign>(
        value: campaign,
        onRetry: () => ref.invalidate(campaignProvider(campaignId)),
        builder: (ContributionCampaign data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.giant,
          ),
          children: <Widget>[
            Text(data.title, style: context.text.titleLarge),
            if (data.description != null) ...<Widget>[
              const SizedBox(height: KSpacing.xxs),
              Text(data.description!, style: context.text.bodySmall),
            ],
            if (data.dueDate != null) ...<Widget>[
              const SizedBox(height: KSpacing.xs),
              Text(
                DateFormatter.date(data.dueDate!, context.localeCode),
                style: context.text.labelMedium,
              ),
            ],
            KSpacing.gapLg,
            if (data.summary != null)
              _SummaryGrid(summary: data.summary!, currency: currency),
            KSpacing.gapLg,
            KSectionHeader(
              title: context.l10n.campaignMembers,
              subtitle: context.l10n.campaignMembersCount(data.entries.length),
            ),
            ...data.entries.map(
              (CampaignEntry entry) => Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: _EntryTile(
                  entry: entry,
                  campaign: data,
                  currency: currency,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.currency});

  final CampaignSummary summary;
  final Currency currency;

  @override
  Widget build(BuildContext context) => KStatGrid(
    tiles: <Widget>[
      // Attendu et encaissé sont deux nombres différents : c'est le principe
      // même du module, et l'écran le montre plutôt que de l'expliquer.
      KStatTile(
        label: context.l10n.treasuryExpected,
        value: MoneyFormatter.compact(summary.expected, currency),
        icon: Icons.receipt_long_outlined,
      ),
      KStatTile(
        label: context.l10n.treasuryCollected,
        value: MoneyFormatter.compact(summary.collected, currency),
        icon: Icons.savings_outlined,
        accent: context.colors.success,
      ),
      KStatTile(
        label: context.l10n.treasuryRemaining,
        value: MoneyFormatter.compact(summary.remaining, currency),
        icon: Icons.hourglass_bottom,
      ),
      KStatTile(
        label: context.l10n.treasuryRecoveryRate,
        // `null` pour une cotisation à montant libre : afficher 0 % ferait
        // croire que personne n'a payé.
        value: summary.recoveryRate == null
            ? '—'
            : '${summary.recoveryRate!.toStringAsFixed(1)} %',
        icon: Icons.percent,
      ),
    ],
  );
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({
    required this.entry,
    required this.campaign,
    required this.currency,
  });

  final CampaignEntry entry;
  final ContributionCampaign campaign;
  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canPay = ref.watch(
      canProvider(Permission.paymentCreate),
    );
    final bool canExempt = ref.watch(canProvider(Permission.contributionExempt));
    final bool settled = entry.status.isSettled;

    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(entry.memberName, style: context.text.titleSmall),
              ),
              _EntryBadge(status: entry.status),
            ],
          ),
          const SizedBox(height: KSpacing.xxs),
          Text(
            context.l10n.campaignPaidOf(
              MoneyFormatter.format(entry.paidAmount, currency),
              MoneyFormatter.format(entry.expectedAmount, currency),
            ),
            style: context.text.bodySmall,
          ),
          if (entry.daysLate > 0) ...<Widget>[
            const SizedBox(height: KSpacing.xxs),
            Text(
              context.l10n.unpaidDaysLate(entry.daysLate),
              style: context.text.labelSmall?.copyWith(
                color: context.colors.danger,
              ),
            ),
          ],
          if (entry.exemptionReason != null) ...<Widget>[
            const SizedBox(height: KSpacing.xxs),
            Text(entry.exemptionReason!, style: context.text.labelSmall),
          ],
          if (!settled && campaign.status.acceptsPayments) ...<Widget>[
            const SizedBox(height: KSpacing.sm),
            Row(
              children: <Widget>[
                if (canPay)
                  KButton.secondary(
                    label: context.l10n.campaignPay,
                    expanded: false,
                    size: KButtonSize.small,
                    onPressed: () => _pay(context, ref),
                  ),
                if (canExempt && entry.paidAmount == 0) ...<Widget>[
                  const SizedBox(width: KSpacing.sm),
                  KButton.ghost(
                    label: context.l10n.campaignExempt,
                    onPressed: () => _exempt(context, ref),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final bool? recorded = await showKSheet<bool>(
      context: context,
      builder: (_) => _PaymentSheet(entry: entry, currency: currency),
    );
    if (recorded ?? false) {
      ref
        ..invalidate(campaignProvider(entry.campaignId))
        ..invalidate(campaignsProvider)
        ..invalidate(financialDashboardProvider)
        ..invalidate(unpaidProvider);
    }
  }

  Future<void> _exempt(BuildContext context, WidgetRef ref) async {
    // §34 : une exemption retire la ligne de l'attendu, on la confirme.
    final bool confirmed = await KConfirmDialog.show(
      context,
      title: context.l10n.campaignExempt,
      message: context.l10n.campaignExemptReason,
      confirmLabel: context.l10n.campaignExempt,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(cashboxRepositoryProvider)
          .exempt(entryId: entry.id);
      ref
        ..invalidate(campaignProvider(entry.campaignId))
        ..invalidate(unpaidProvider);
      if (context.mounted) {
        context.showMessage(context.l10n.campaignExempted);
      }
    } on Object catch (error) {
      if (context.mounted) {
        context.showMessage(
          ErrorMapper.message(context.l10n, error),
          isError: true,
        );
      }
    }
  }
}

class _EntryBadge extends StatelessWidget {
  const _EntryBadge({required this.status});

  final CampaignEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (status) {
      CampaignEntryStatus.paid => (
        context.colors.successSurface,
        context.colors.success,
      ),
      CampaignEntryStatus.late_ => (
        context.colors.dangerSurface,
        context.colors.danger,
      ),
      _ => (context.colors.surfaceMuted, context.colors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        status.code,
        style: context.text.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// Saisie d'un règlement.
///
/// Le montant est pré-rempli avec le reste dû : c'est le cas courant, et cela
/// évite le trop-perçu, que le serveur refuse.
class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.entry, required this.currency});

  final CampaignEntry entry;
  final Currency currency;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.entry.remainingAmount > 0
        ? widget.entry.remainingAmount.toStringAsFixed(0)
        : '',
  );
  final TextEditingController _reference = TextEditingController();

  String _method = 'cash';
  bool _saving = false;

  static const List<(String, String)> _methods = <(String, String)>[
    ('cash', 'Espèces'),
    ('wave', 'Wave'),
    ('orange_money', 'Orange Money'),
    ('mtn_momo', 'MTN MoMo'),
    ('moov_money', 'Moov Money'),
    ('bank_transfer', 'Virement'),
    ('other', 'Autre'),
  ];

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.entry.memberName, style: context.text.titleMedium),
        const SizedBox(height: KSpacing.xxs),
        Text(
          context.l10n.campaignPaidOf(
            MoneyFormatter.format(widget.entry.paidAmount, widget.currency),
            MoneyFormatter.format(widget.entry.expectedAmount, widget.currency),
          ),
          style: context.text.bodySmall,
        ),
        KSpacing.gapMd,
        KTextField(
          controller: _amount,
          label: context.l10n.campaignPaymentAmount,
          keyboardType: TextInputType.number,
          validator: (String? value) =>
              Validators.isPositiveAmount(value ?? '')
              ? null
              : context.l10n.commonRequiredField,
        ),
        KSpacing.gapSm,
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: InputDecoration(
            labelText: context.l10n.campaignPaymentMethod,
          ),
          items: _methods
              .map(
                ((String, String) item) => DropdownMenuItem<String>(
                  value: item.$1,
                  child: Text(item.$2),
                ),
              )
              .toList(growable: false),
          onChanged: (String? value) =>
              setState(() => _method = value ?? 'cash'),
        ),
        KSpacing.gapSm,
        KTextField(
          controller: _reference,
          label: context.l10n.campaignPaymentReference,
        ),
        KSpacing.gapLg,
        KButton(
          label: context.l10n.campaignPay,
          isLoading: _saving,
          onPressed: _saving ? null : _submit,
        ),
        KSpacing.gapMd,
      ],
    ),
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(cashboxRepositoryProvider)
          .recordPayment(
            entryId: widget.entry.id,
            amount: Validators.parseAmount(_amount.text) ?? 0,
            paymentMethod: _method,
            reference: _reference.text.trim().isEmpty
                ? null
                : _reference.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      context.showMessage(context.l10n.campaignPaymentSaved);
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
