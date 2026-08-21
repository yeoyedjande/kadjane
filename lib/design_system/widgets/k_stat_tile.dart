import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/theme/app_typography.dart';

/// Tuile de statistique : icône, libellé, valeur mise en avant.
class KStatTile extends StatelessWidget {
  const KStatTile({
    required this.label,
    required this.value,
    super.key,
    this.icon,
    this.accent,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? context.colors.brand;
    final Widget content = Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: KRadius.card,
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(KSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KRadius.sm),
              ),
              child: Icon(icon, size: KSizes.iconSm, color: color),
            ),
            const SizedBox(height: KSpacing.md),
          ],
          Text(
            value,
            style: AppTypography.amount(context.colors.textPrimary, size: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: KSpacing.xxs),
          Text(
            label,
            style: context.text.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: KSpacing.xs),
            Text(
              caption!,
              style: context.text.labelSmall?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return InkWell(onTap: onTap, borderRadius: KRadius.card, child: content);
  }
}

/// Grille responsive de tuiles statistiques.
class KStatGrid extends StatelessWidget {
  const KStatGrid({required this.tiles, super.key, this.columns});

  final List<Widget> tiles;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final int count = columns ?? (context.isWide ? 4 : 2);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = KSpacing.md;
        final double itemWidth =
            (constraints.maxWidth - gap * (count - 1)) / count;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles
              .map((Widget tile) => SizedBox(width: itemWidth, child: tile))
              .toList(growable: false),
        );
      },
    );
  }
}
