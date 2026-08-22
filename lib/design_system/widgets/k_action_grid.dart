import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Une tuile d'action : une icône, un libellé, une destination.
class KAction {
  const KAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Grille de raccourcis, **deux par ligne** sur téléphone.
///
/// Les tuiles se partagent la largeur disponible. Une largeur fixe laissait un
/// bord droit irrégulier et des colonnes d'aspect différent selon la taille de
/// l'écran. Au-delà de [wideBreakpoint] — tablette, ou téléphone en paysage —
/// on passe à quatre colonnes plutôt que d'étirer démesurément chaque tuile.
class KActionGrid extends StatelessWidget {
  const KActionGrid({required this.actions, super.key});

  final List<KAction> actions;

  static const double wideBreakpoint = 600;
  static const double tileHeight = 104;

  /// Nombre de colonnes pour une largeur donnée.
  ///
  /// Exposé pour que la règle soit vérifiable sans construire la grille.
  static int columnsFor(double width) => width >= wideBreakpoint ? 4 : 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = columnsFor(constraints.maxWidth);
        final double gaps = KSpacing.md * (columns - 1);
        final double tileWidth = (constraints.maxWidth - gaps) / columns;

        return Wrap(
          spacing: KSpacing.md,
          runSpacing: KSpacing.md,
          children: <Widget>[
            for (final KAction action in actions)
              SizedBox(
                width: tileWidth,
                height: tileHeight,
                child: _Tile(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action});

  final KAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: KRadius.card,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: KSpacing.md,
          horizontal: KSpacing.sm,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: KRadius.card,
          border: Border.all(color: context.colors.divider),
        ),
        child: Column(
          // La hauteur est imposée par la grille : on centre pour que les
          // libellés d'une et de deux lignes s'alignent entre eux.
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(action.icon, color: context.colors.brand),
            const SizedBox(height: KSpacing.sm),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: context.text.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
