import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/features/auth/presentation/widgets/auth_scaffold.dart';

/// Saisie du code de vérification à 6 chiffres.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.target, super.key});

  final String target;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _code = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final String token = await ref
          .read(authRepositoryProvider)
          .verifyOtp(target: widget.target, code: _code.text.trim());
      if (mounted) {
        context.push('${AppRoutes.resetPassword}?token=$token');
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
    return AuthScaffold(
      title: context.l10n.authOtpTitle,
      subtitle: context.l10n.authOtpSubtitle(widget.target),
      footer: KButton(
        label: context.l10n.commonConfirm,
        isLoading: _isLoading,
        onPressed: _code.text.trim().length == 6 ? _submit : null,
      ),
      children: <Widget>[
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: context.text.displaySmall?.copyWith(letterSpacing: 12),
          decoration: const InputDecoration(counterText: ''),
          onChanged: (_) => setState(() {}),
        ),
        KSpacing.gapLg,
        Center(
          child: TextButton.icon(
            onPressed: () async {
              await ref.read(authRepositoryProvider).requestOtp(widget.target);
              if (context.mounted) {
                context.showMessage(context.l10n.authSendCode);
              }
            },
            icon: const Icon(Icons.refresh, size: KSizes.iconSm),
            label: Text(context.l10n.authResendCode),
          ),
        ),
      ],
    );
  }
}
