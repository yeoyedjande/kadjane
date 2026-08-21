import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/features/auth/presentation/widgets/auth_scaffold.dart';

/// Définition d'un nouveau mot de passe après vérification du code.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.resetToken, super.key});

  final String resetToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
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
          .resetPassword(
            resetToken: widget.resetToken,
            newPassword: _password.text,
          );
      if (mounted) {
        context
          ..showMessage(context.l10n.profileSaved)
          ..go(AppRoutes.login);
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
    return Form(
      key: _formKey,
      child: AuthScaffold(
        title: context.l10n.authResetPasswordTitle,
        subtitle: context.l10n.authResetPasswordSubtitle,
        footer: KButton(
          label: context.l10n.commonSave,
          isLoading: _isLoading,
          onPressed: _submit,
        ),
        children: <Widget>[
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
        ],
      ),
    );
  }
}
