import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/permission.dart';

/// Paramètres de l'organisation : identité, règles et responsables.
class OrganizationSettingsScreen extends ConsumerStatefulWidget {
  const OrganizationSettingsScreen({super.key, this.embedded = false});

  /// Intégré dans la console d'administration : pas de barre d'application.
  final bool embedded;

  @override
  ConsumerState<OrganizationSettingsScreen> createState() =>
      _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState
    extends ConsumerState<OrganizationSettingsScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _rules = TextEditingController();

  Organization? _loaded;
  Currency _currency = Currency.xof;
  bool _requireFullPayment = true;
  bool _allowOverride = true;
  int _graceDays = 3;
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _hydrate(Organization organization) {
    if (_loaded?.id == organization.id) {
      return;
    }
    _loaded = organization;
    _name.text = organization.name;
    _description.text = organization.description ?? '';
    _phone.text = organization.phone ?? '';
    _email.text = organization.email ?? '';
    _address.text = organization.address ?? '';
    _rules.text = organization.rules ?? '';
    _currency = organization.currency;
    _requireFullPayment = organization.settings.requireFullPaymentBeforeDraw;
    _allowOverride = organization.settings.allowDrawOverride;
    _graceDays = organization.settings.latePaymentGraceDays;
  }

  Future<void> _submit(Organization organization) async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(organizationRepositoryProvider)
          .update(
            organization.copyWith(
              name: _name.text.trim(),
              description: _description.text.trim(),
              phone: _phone.text.trim(),
              email: _email.text.trim(),
              address: _address.text.trim(),
              rules: _rules.text.trim(),
              currency: _currency,
              settings: organization.settings.copyWith(
                requireFullPaymentBeforeDraw: _requireFullPayment,
                allowDrawOverride: _allowOverride,
                latePaymentGraceDays: _graceDays,
              ),
            ),
          );
      ref
        ..invalidate(activeOrganizationProvider)
        ..invalidate(userOrganizationsProvider);
      if (mounted) {
        context.showMessage(context.l10n.orgSaved);
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
    final AsyncValue<Organization?> organization = ref.watch(
      activeOrganizationProvider,
    );
    final bool canEdit = ref.watch(canProvider(Permission.organizationEdit));
    final List<OrganizationMember> officers =
        ref.watch(_officersProvider).valueOrNull ??
        const <OrganizationMember>[];

    final Widget body = KAsyncView<Organization?>(
      value: organization,
      onRetry: () => ref.invalidate(activeOrganizationProvider),
      isEmpty: (Organization? data) => data == null,
      builder: (Organization? data) {
        _hydrate(data!);
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xxxl,
          ),
          children: <Widget>[
            KTextField(
              label: context.l10n.orgName,
              controller: _name,
              enabled: canEdit,
              validator: (String? value) => Validators.isBlank(value)
                  ? context.l10n.commonRequiredField
                  : null,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.tontinesDescription,
              controller: _description,
              enabled: canEdit,
              maxLines: 3,
            ),
            KSpacing.gapLg,
            KDropdownField<Currency>(
              label: context.l10n.tontinesCurrency,
              value: _currency,
              items: Currency.values,
              itemLabel: (Currency currency) =>
                  '${currency.code} · ${currency.symbol}',
              onChanged: canEdit
                  ? (Currency? value) =>
                        setState(() => _currency = value ?? Currency.xof)
                  : (Currency? value) {},
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.authPhone,
              controller: _phone,
              enabled: canEdit,
              keyboardType: TextInputType.phone,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.authEmail,
              controller: _email,
              enabled: canEdit,
              keyboardType: TextInputType.emailAddress,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.orgAddress,
              controller: _address,
              enabled: canEdit,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.orgRules,
              controller: _rules,
              enabled: canEdit,
              maxLines: 4,
            ),
            KSpacing.gapXl,
            KCard(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _requireFullPayment,
                    title: Text(
                      context.l10n.orgRequireFullPayment,
                      style: context.text.titleSmall,
                    ),
                    onChanged: canEdit
                        ? (bool value) =>
                              setState(() => _requireFullPayment = value)
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _allowOverride,
                    title: Text(
                      context.l10n.orgAllowOverride,
                      style: context.text.titleSmall,
                    ),
                    onChanged: canEdit
                        ? (bool value) => setState(() => _allowOverride = value)
                        : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.l10n.orgGraceDays,
                      style: context.text.titleSmall,
                    ),
                    trailing: DropdownButton<int>(
                      value: _graceDays,
                      underline: const SizedBox.shrink(),
                      items: List<DropdownMenuItem<int>>.generate(
                        11,
                        (int index) => DropdownMenuItem<int>(
                          value: index,
                          child: Text('$index'),
                        ),
                      ),
                      onChanged: canEdit
                          ? (int? value) =>
                                setState(() => _graceDays = value ?? 3)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.gapLg,
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  KSectionHeader(title: context.l10n.orgOfficers),
                  ...officers.map(
                    (OrganizationMember officer) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: KAvatar(
                        name: officer.fullName,
                        size: KSizes.avatarSm,
                      ),
                      title: Text(
                        officer.fullName,
                        style: context.text.titleSmall,
                      ),
                      trailing: KBadge(
                        label: Labels.role(context.l10n, officer.role),
                        tone: StatusTone(
                          context.colors.brand,
                          context.scheme.primaryContainer,
                        ),
                        compact: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit) ...<Widget>[
              KSpacing.gapXl,
              KButton(
                label: context.l10n.commonSave,
                isLoading: _isSaving,
                onPressed: () => _submit(data),
              ),
            ],
          ],
        );
      },
    );

    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.orgSettingsTitle)),
      body: body,
    );
  }
}

/// Responsables de l'organisation active.
final AutoDisposeFutureProvider<List<OrganizationMember>> _officersProvider =
    FutureProvider.autoDispose<List<OrganizationMember>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <OrganizationMember>[];
      }
      return ref.watch(organizationRepositoryProvider).officers(organizationId);
    });
