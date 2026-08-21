import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/theme/app_shadows.dart';

/// Carte standard : fond de surface, bordure douce, coins arrondis.
class KCard extends StatelessWidget {
  const KCard({
    required this.child,
    super.key,
    this.padding = KSpacing.card,
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.scheme.surface,
        borderRadius: KRadius.card,
        border: Border.all(color: borderColor ?? context.colors.divider),
        boxShadow: elevated ? KShadows.card(context.theme.brightness) : null,
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: KRadius.card,
      child: InkWell(onTap: onTap, borderRadius: KRadius.card, child: content),
    );
  }
}

/// En-tête de section : titre + action facultative.
class KSectionHeader extends StatelessWidget {
  const KSectionHeader({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.text.titleMedium),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: KSpacing.xxs),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Ligne « libellé — valeur » utilisée dans les fiches détail.
class KDetailRow extends StatelessWidget {
  const KDetailRow({
    required this.label,
    required this.value,
    super.key,
    this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: KSizes.iconSm, color: context.colors.textTertiary),
            const SizedBox(width: KSpacing.sm),
          ],
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.text.titleSmall?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
