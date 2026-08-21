import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Mise en page commune aux écrans d'authentification.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
    this.showBackButton = true,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBackButton;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBackButton
          ? AppBar(leading: const BackButton(), toolbarHeight: 56)
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSizes.contentMaxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.xl,
                KSpacing.lg,
                KSpacing.xl,
                KSpacing.xxl,
              ),
              children: <Widget>[
                Text(title, style: context.text.headlineMedium),
                const SizedBox(height: KSpacing.sm),
                Text(subtitle, style: context.text.bodyMedium),
                const SizedBox(height: KSpacing.xxl),
                ...children,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: footer == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.xl,
                  0,
                  KSpacing.xl,
                  KSpacing.lg,
                ),
                child: footer,
              ),
            ),
    );
  }
}
