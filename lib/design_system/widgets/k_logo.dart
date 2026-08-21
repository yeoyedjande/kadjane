import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_colors.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Marque Kadjane : monogramme sur dégradé vert, ponctué d'un point or.
class KLogo extends StatelessWidget {
  const KLogo({super.key, this.size = 64, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final Widget mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppPalette.primary, AppPalette.green900],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Text(
            'K',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          Positioned(
            right: size * 0.18,
            bottom: size * 0.2,
            child: Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: const BoxDecoration(
                color: AppPalette.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        const SizedBox(height: KSpacing.lg),
        Text(context.l10n.appName, style: context.text.headlineMedium),
        const SizedBox(height: KSpacing.xs),
        Text(
          context.l10n.appTagline,
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
