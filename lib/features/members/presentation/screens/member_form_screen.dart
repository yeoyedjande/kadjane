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
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';
import 'package:kadjane/features/members/presentation/providers/member_providers.dart';

/// Ajout d'un membre à l'organisation.
class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key});

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();

  OrgRole _role = OrgRole.member;
  Gender _gender = Gender.unspecified;
  MemberStatus _status = MemberStatus.active;
  DateTime? _birthDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
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
          .read(memberRepositoryProvider)
          .create(
            organizationId: organizationId,
            actorMemberId: actor.id,
            draft: MemberDraft(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              phone: _phone.text.trim(),
              role: _role,
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              gender: _gender,
              birthDate: _birthDate,
              status: _status,
            ),
          );
      ref.invalidate(membersProvider);
      refreshOrganizationData(ref);
      if (mounted) {
        Navigator.of(context).pop();
        context.showMessage(context.l10n.membersSaved);
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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.membersAdd)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: KButton(
            label: context.l10n.commonSave,
            isLoading: _isSaving,
            onPressed: _submit,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.lg),
          children: <Widget>[
            KTextField(
              label: context.l10n.authFirstName,
              controller: _firstName,
              textInputAction: TextInputAction.next,
              validator: (String? value) => Validators.isBlank(value)
                  ? context.l10n.commonRequiredField
                  : null,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.authLastName,
              controller: _lastName,
              textInputAction: TextInputAction.next,
              validator: (String? value) => Validators.isBlank(value)
                  ? context.l10n.commonRequiredField
                  : null,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.authPhone,
              controller: _phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (String? value) {
                if (Validators.isBlank(value)) {
                  return context.l10n.commonRequiredField;
                }
                return Validators.isValidPhone(value!)
                    ? null
                    : context.l10n.authInvalidPhone;
              },
            ),
            KSpacing.gapLg,
            KTextField(
              label:
                  '${context.l10n.authEmail} (${context.l10n.commonOptional})',
              controller: _email,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (String? value) {
                if (Validators.isBlank(value)) {
                  return null;
                }
                return Validators.isValidEmail(value!)
                    ? null
                    : context.l10n.authInvalidEmail;
              },
            ),
            KSpacing.gapLg,
            KDropdownField<OrgRole>(
              label: context.l10n.membersRole,
              value: _role,
              items: OrgRole.values
                  .where((OrgRole role) => role != OrgRole.superAdmin)
                  .toList(growable: false),
              itemLabel: (OrgRole role) => Labels.role(context.l10n, role),
              onChanged: (OrgRole? value) =>
                  setState(() => _role = value ?? OrgRole.member),
            ),
            KSpacing.gapLg,
            KDropdownField<Gender>(
              label:
                  '${context.l10n.membersGender} (${context.l10n.commonOptional})',
              value: _gender,
              items: Gender.values,
              itemLabel: (Gender gender) => Labels.gender(context.l10n, gender),
              onChanged: (Gender? value) =>
                  setState(() => _gender = value ?? Gender.unspecified),
            ),
            KSpacing.gapLg,
            KDateField(
              label:
                  '${context.l10n.membersBirthDate} (${context.l10n.commonOptional})',
              value: _birthDate,
              firstDate: DateTime(1930),
              lastDate: DateTime.now(),
              onChanged: (DateTime value) => setState(() => _birthDate = value),
            ),
            KSpacing.gapLg,
            KDropdownField<MemberStatus>(
              label: context.l10n.commonStatus,
              value: _status,
              items: MemberStatus.values,
              itemLabel: (MemberStatus status) =>
                  Labels.memberStatus(context.l10n, status),
              onChanged: (MemberStatus? value) =>
                  setState(() => _status = value ?? MemberStatus.active),
            ),
            KSpacing.gapLg,
            Text(context.l10n.membersInviteSoon, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}
