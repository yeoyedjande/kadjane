import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Pastille d'état (statut de paiement, de tontine, de tirage...).
class KBadge extends StatelessWidget {
  const KBadge({
    required this.label,
    required this.tone,
    super.key,
    this.icon,
    this.compact = false,
  });

  /// Badge neutre, sans connotation d'état.
  KBadge.neutral({
    required this.label,
    required BuildContext context,
    super.key,
    this.icon,
    this.compact = false,
  }) : tone = StatusTone(
         context.colors.textSecondary,
         context.colors.surfaceMuted,
       );

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? KSpacing.sm : KSpacing.md,
        vertical: compact ? KSpacing.xxs : KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: KRadius.badge,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: tone.foreground),
            const SizedBox(width: KSpacing.xs),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: tone.foreground,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit point coloré, pour les listes denses.
class KStatusDot extends StatelessWidget {
  const KStatusDot({required this.color, super.key, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Compteur de notifications non lues.
class KCountBadge extends StatelessWidget {
  const KCountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: context.colors.danger,
        borderRadius: KRadius.badge,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: context.text.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }
}
