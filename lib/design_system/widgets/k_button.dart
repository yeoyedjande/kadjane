import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

enum KButtonVariant { primary, secondary, ghost, danger }

enum KButtonSize { regular, small }

/// Bouton unique de l'application (aucun style local dans les écrans).
class KButton extends StatelessWidget {
  const KButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = KButtonVariant.primary,
    this.size = KButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  const KButton.secondary({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = KButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  }) : variant = KButtonVariant.secondary;

  const KButton.ghost({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = KButtonSize.small,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  }) : variant = KButtonVariant.ghost;

  const KButton.danger({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = KButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  }) : variant = KButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final double height = size == KButtonSize.regular
        ? KSizes.buttonHeight
        : KSizes.buttonHeightSm;
    final VoidCallback? effectiveOnPressed = isLoading ? null : onPressed;
    final Widget child = _Content(
      label: label,
      icon: icon,
      isLoading: isLoading,
      variant: variant,
    );

    final Widget button;
    switch (variant) {
      case KButtonVariant.primary:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height),
            backgroundColor: context.scheme.primary,
            foregroundColor: context.scheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
            shape: const RoundedRectangleBorder(borderRadius: KRadius.button),
          ),
          child: child,
        );
      case KButtonVariant.danger:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height),
            backgroundColor: context.colors.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
            shape: const RoundedRectangleBorder(borderRadius: KRadius.button),
          ),
          child: child,
        );
      case KButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
            shape: const RoundedRectangleBorder(borderRadius: KRadius.button),
            side: BorderSide(color: context.colors.divider),
          ),
          child: child,
        );
      case KButtonVariant.ghost:
        button = TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
            shape: const RoundedRectangleBorder(borderRadius: KRadius.button),
          ),
          child: child,
        );
    }
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.variant,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final KButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: KSizes.iconSm,
        width: KSizes.iconSm,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color:
              variant == KButtonVariant.primary ||
                  variant == KButtonVariant.danger
              ? context.scheme.onPrimary
              : context.scheme.primary,
        ),
      );
    }
    if (icon == null) {
      return Text(label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: KSizes.iconSm),
        const SizedBox(width: KSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
