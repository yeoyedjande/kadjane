import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/features/auth/presentation/widgets/auth_scaffold.dart';

/// Demande d'un code de vérification pour réinitialiser le mot de passe.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _target = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final String target = _target.text.trim();
      await ref.read(authRepositoryProvider).requestOtp(target);
      if (mounted) {
        context.push('${AppRoutes.otp}?target=${Uri.encodeComponent(target)}');
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
        title: context.l10n.authForgotPassword,
        subtitle: context.l10n.authForgotPasswordSubtitle,
        footer: KButton(
          label: context.l10n.authSendCode,
          isLoading: _isLoading,
          onPressed: _submit,
        ),
        children: <Widget>[
          KTextField(
            label: context.l10n.authPhone,
            controller: _target,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (String? value) {
              if (Validators.isBlank(value)) {
                return context.l10n.commonRequiredField;
              }
              return Validators.isValidPhone(value!) ||
                      Validators.isValidEmail(value)
                  ? null
                  : context.l10n.authInvalidPhone;
            },
          ),
        ],
      ),
    );
  }
}
