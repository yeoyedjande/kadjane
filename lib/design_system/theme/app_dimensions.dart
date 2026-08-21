import 'package:flutter/widgets.dart';

/// Échelle d'espacement (multiples de 4).
class KSpacing {
  const KSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// Marge horizontale standard des écrans.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);

  /// Marge intérieure standard d'une carte.
  static const EdgeInsets card = EdgeInsets.all(lg);

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);
}

/// Rayons de bordure.
class KRadius {
  const KRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
  static const BorderRadius badge = BorderRadius.all(Radius.circular(pill));
}

/// Durées d'animation.
class KDurations {
  const KDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Durée de rotation de la roue de tirage.
  static const Duration wheelSpin = Duration(milliseconds: 4200);
}

/// Tailles récurrentes.
class KSizes {
  const KSizes._();

  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double avatarXl = 88;
  static const double buttonHeight = 52;
  static const double buttonHeightSm = 40;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double progressBar = 8;

  /// Largeur au-delà de laquelle on passe en présentation deux colonnes.
  static const double tabletBreakpoint = 720;
  static const double contentMaxWidth = 640;
}
