import 'package:flutter/material.dart';

/// Typographie Kadjane.
///
/// Police système (aucun asset à télécharger) mais échelle, graisses et
/// interlettrages centralisés : les écrans utilisent uniquement
/// `Theme.of(context).textTheme`.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) => TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: primary,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: primary,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: primary,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: primary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: primary,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: secondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: secondary,
    ),
  );

  /// Style dédié aux montants (chiffres alignés, graisse forte).
  static TextStyle amount(Color color, {double size = 24}) => TextStyle(
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: color,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}
