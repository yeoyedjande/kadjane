import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_logo.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/auth_session.dart';

/// Connexion par téléphone ou email.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifier = TextEditingController(
    text: '+225 07 00 00 00 01',
  );
  final TextEditingController _password = TextEditingController(
    text: 'kadjane',
  );

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signIn(identifier: _identifier.text.trim(), password: _password.text);
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSizes.contentMaxWidth),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(KSpacing.xl),
                children: <Widget>[
                  const SizedBox(height: KSpacing.xxl),
                  const Center(child: KLogo(size: 72)),
                  const SizedBox(height: KSpacing.xxl),
                  Text(
                    context.l10n.authSignIn,
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: KSpacing.sm),
                  Text(
                    context.l10n.authSignInSubtitle,
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: KSpacing.xxl),
                  KTextField(
                    label:
                        '${context.l10n.authPhone} / ${context.l10n.authEmail}',
                    controller: _identifier,
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    validator: (String? value) => Validators.isBlank(value)
                        ? context.l10n.commonRequiredField
                        : null,
                  ),
                  KSpacing.gapLg,
                  KPasswordField(
                    label: context.l10n.authPassword,
                    controller: _password,
                    textInputAction: TextInputAction.done,
                    validator: (String? value) => Validators.isBlank(value)
                        ? context.l10n.commonRequiredField
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: Text(context.l10n.authForgotPassword),
                    ),
                  ),
                  KSpacing.gapMd,
                  KButton(
                    label: context.l10n.authSignIn,
                    isLoading: state.isLoading,
                    onPressed: _submit,
                  ),
                  KSpacing.gapLg,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        context.l10n.authNoAccount,
                        style: context.text.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.register),
                        child: Text(context.l10n.authSignUp),
                      ),
                    ],
                  ),
                  KSpacing.gapLg,
                  Container(
                    padding: const EdgeInsets.all(KSpacing.md),
                    decoration: BoxDecoration(
                      color: context.colors.infoSurface,
                      borderRadius: KRadius.field,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          size: KSizes.iconSm,
                          color: context.colors.info,
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: Text(
                            context.l10n.authDemoHint,
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
