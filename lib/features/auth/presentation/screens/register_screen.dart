import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/repositories/auth_repository.dart';
import 'package:kadjane/features/auth/presentation/widgets/auth_scaffold.dart';

/// Création d'un compte Kadjane.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .register(
          RegisterDraft(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthSession?> state = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (
      AsyncValue<AuthSession?>? previous,
      AsyncValue<AuthSession?> next,
    ) {
      if (next.hasError && !next.isLoading) {
        context.showMessage(
          ErrorMapper.message(context.l10n, next.error!),
          isError: true,
        );
      }
    });

    return Form(
      key: _formKey,
      child: AuthScaffold(
        title: context.l10n.authSignUp,
        subtitle: context.l10n.authSignUpSubtitle,
        footer: KButton(
          label: context.l10n.authSignUp,
          isLoading: state.isLoading,
          onPressed: _submit,
        ),
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
            label: '${context.l10n.authEmail} (${context.l10n.commonOptional})',
            controller: _email,
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
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
          KPasswordField(
            label: context.l10n.authPassword,
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
