import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/user.dart';

/// Modification des informations personnelles.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final User? _user = ref.read(currentUserProvider);
  late final TextEditingController _firstName = TextEditingController(
    text: _user?.firstName ?? '',
  );
  late final TextEditingController _lastName = TextEditingController(
    text: _user?.lastName ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: _user?.phone ?? '',
  );
  late final TextEditingController _email = TextEditingController(
    text: _user?.email ?? '',
  );
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
    if (!(_formKey.currentState?.validate() ?? false) || _user == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            _user.copyWith(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              phone: _phone.text.trim(),
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            ),
          );
      if (mounted) {
        Navigator.of(context).pop();
        context.showMessage(context.l10n.profileSaved);
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
      appBar: AppBar(title: Text(context.l10n.profileEdit)),
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
              validator: (String? value) => Validators.isBlank(value)
                  ? context.l10n.commonRequiredField
                  : null,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.authLastName,
              controller: _lastName,
              validator: (String? value) => Validators.isBlank(value)
                  ? context.l10n.commonRequiredField
                  : null,
            ),
            KSpacing.gapLg,
            KTextField(
              label: context.l10n.authPhone,
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
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
              label: context.l10n.authEmail,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline,
              validator: (String? value) {
                if (Validators.isBlank(value)) {
                  return null;
                }
                return Validators.isValidEmail(value!)
                    ? null
                    : context.l10n.authInvalidEmail;
              },
            ),
          ],
        ),
      ),
    );
  }
}
