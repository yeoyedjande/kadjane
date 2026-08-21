import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';

/// Changement de mot de passe par un membre connecté.
///
/// Les comptes sont créés depuis le back-office avec un mot de passe
/// provisoire, transmis par l'administrateur. Cet écran permet au membre de
/// s'en affranchir. Le serveur ferme les autres sessions au passage.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      if (mounted) {
        context.showMessage(context.l10n.authPasswordChanged);
        Navigator.of(context).pop();
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.authChangePassword)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.lg),
          children: <Widget>[
            Text(
              context.l10n.authChangePasswordHint,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            KSpacing.gapLg,
            KPasswordField(
              label: context.l10n.authCurrentPassword,
              controller: _current,
              textInputAction: TextInputAction.next,
              validator: (String? value) => Validators.isBlank(value)
                  ? context.l10n.commonRequiredField
                  : null,
            ),
            KSpacing.gapLg,
            KPasswordField(
              label: context.l10n.authNewPassword,
              controller: _password,
              textInputAction: TextInputAction.next,
              validator: (String? value) {
                if (Validators.isBlank(value)) {
                  return context.l10n.commonRequiredField;
                }
                return Validators.isValidPassword(value!)
                    ? null
                    : context.l10n.authPasswordTooShort;
              },
            ),
            KSpacing.gapLg,
            KPasswordField(
              label: context.l10n.authConfirmPassword,
              controller: _confirm,
              textInputAction: TextInputAction.done,
              validator: (String? value) => value == _password.text
                  ? null
                  : context.l10n.authPasswordMismatch,
            ),
            KSpacing.gapXl,
            KButton(
              label: context.l10n.commonSave,
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
