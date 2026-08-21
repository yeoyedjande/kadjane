import 'package:flutter/material.dart';

/// Palette Kadjane.
///
/// Identité africaine contemporaine : vert profond (confiance, communauté),
/// or ocre (valeur, célébration), terre cuite (chaleur). Aucun écran ne doit
/// écrire une couleur en dur : tout passe par [KadjaneColors] ou le
/// `ColorScheme` du thème.
class AppPalette {
  const AppPalette._();

  // Vert Kadjane
  static const Color green900 = Color(0xFF063C30);
  static const Color primary = Color(0xFF0E6B54);
  static const Color primaryDark = Color(0xFF0A5040);
  static const Color primaryLight = Color(0xFF34C79B);
  static const Color primaryContainer = Color(0xFFCFE9DF);

  // Or ocre
  static const Color gold = Color(0xFFE0A33E);
  static const Color goldContainer = Color(0xFFFAEBD0);

  // Terre cuite
  static const Color terracotta = Color(0xFFC1502E);
  static const Color terracottaContainer = Color(0xFFF8DFD6);

  // Neutres chauds — mode clair
  static const Color background = Color(0xFFF6F5F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0EFEA);
  static const Color outline = Color(0xFFE2DFD8);
  static const Color textPrimary = Color(0xFF16211D);
  static const Color textSecondary = Color(0xFF5C6A64);
  static const Color textTertiary = Color(0xFF8A9691);

  // Neutres — mode sombre
  static const Color backgroundDark = Color(0xFF0D1411);
  static const Color surfaceDark = Color(0xFF131C18);
  static const Color surfaceMutedDark = Color(0xFF1A2520);
  static const Color outlineDark = Color(0xFF26332D);
  static const Color textPrimaryDark = Color(0xFFECF3EF);
  static const Color textSecondaryDark = Color(0xFFA5B5AE);
  static const Color textTertiaryDark = Color(0xFF75857E);

  // Sémantiques
  static const Color success = Color(0xFF1E8E5A);
  static const Color successDark = Color(0xFF3FBE85);
  static const Color warning = Color(0xFFD98324);
  static const Color warningDark = Color(0xFFEBA85C);
  static const Color danger = Color(0xFFC2352B);
  static const Color dangerDark = Color(0xFFE86A60);
  static const Color info = Color(0xFF2E6F9E);
  static const Color infoDark = Color(0xFF5FA4D0);
}

/// Couleurs sémantiques complémentaires au `ColorScheme` Material 3.
@immutable
class KadjaneColors extends ThemeExtension<KadjaneColors> {
  const KadjaneColors({
    required this.brand,
    required this.accent,
    required this.accentContainer,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.info,
    required this.infoSurface,
    required this.divider,
    required this.chartLine,
    required this.chartArea,
    required this.wheelColors,
  });

  final Color brand;
  final Color accent;
  final Color accentContainer;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color danger;
  final Color dangerSurface;
  final Color info;
  final Color infoSurface;
  final Color divider;
  final Color chartLine;
  final Color chartArea;

  /// Couleurs alternées des secteurs de la roue de tirage.
  final List<Color> wheelColors;

  static const KadjaneColors light = KadjaneColors(
    brand: AppPalette.primary,
    accent: AppPalette.gold,
    accentContainer: AppPalette.goldContainer,
    surfaceMuted: AppPalette.surfaceMuted,
    textPrimary: AppPalette.textPrimary,
    textSecondary: AppPalette.textSecondary,
    textTertiary: AppPalette.textTertiary,
    success: AppPalette.success,
    successSurface: Color(0xFFDDF2E6),
    warning: AppPalette.warning,
    warningSurface: Color(0xFFFCEDD8),
    danger: AppPalette.danger,
    dangerSurface: Color(0xFFFADEDB),
    info: AppPalette.info,
    infoSurface: Color(0xFFDDEBF6),
    divider: AppPalette.outline,
    chartLine: AppPalette.primary,
    chartArea: Color(0x1A0E6B54),
    wheelColors: <Color>[
      AppPalette.primary,
      AppPalette.gold,
      AppPalette.terracotta,
      Color(0xFF2E6F9E),
      Color(0xFF6B4E9E),
      Color(0xFF1E8E5A),
    ],
  );

  static const KadjaneColors dark = KadjaneColors(
    brand: AppPalette.primaryLight,
    accent: AppPalette.gold,
    accentContainer: Color(0xFF3B2E14),
    surfaceMuted: AppPalette.surfaceMutedDark,
    textPrimary: AppPalette.textPrimaryDark,
    textSecondary: AppPalette.textSecondaryDark,
    textTertiary: AppPalette.textTertiaryDark,
    success: AppPalette.successDark,
    successSurface: Color(0xFF12312A),
    warning: AppPalette.warningDark,
    warningSurface: Color(0xFF33260F),
    danger: AppPalette.dangerDark,
    dangerSurface: Color(0xFF3A1D1A),
    info: AppPalette.infoDark,
    infoSurface: Color(0xFF13293A),
    divider: AppPalette.outlineDark,
    chartLine: AppPalette.primaryLight,
    chartArea: Color(0x2634C79B),
    wheelColors: <Color>[
      AppPalette.primaryLight,
      AppPalette.gold,
      Color(0xFFE07A55),
      Color(0xFF5FA4D0),
      Color(0xFF9B84D4),
      Color(0xFF3FBE85),
    ],
  );

  @override
  KadjaneColors copyWith({
    Color? brand,
    Color? accent,
    Color? accentContainer,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? danger,
    Color? dangerSurface,
    Color? info,
    Color? infoSurface,
    Color? divider,
    Color? chartLine,
    Color? chartArea,
    List<Color>? wheelColors,
  }) => KadjaneColors(
    brand: brand ?? this.brand,
    accent: accent ?? this.accent,
    accentContainer: accentContainer ?? this.accentContainer,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    success: success ?? this.success,
    successSurface: successSurface ?? this.successSurface,
    warning: warning ?? this.warning,
    warningSurface: warningSurface ?? this.warningSurface,
    danger: danger ?? this.danger,
    dangerSurface: dangerSurface ?? this.dangerSurface,
    info: info ?? this.info,
    infoSurface: infoSurface ?? this.infoSurface,
    divider: divider ?? this.divider,
    chartLine: chartLine ?? this.chartLine,
    chartArea: chartArea ?? this.chartArea,
    wheelColors: wheelColors ?? this.wheelColors,
  );

  @override
  KadjaneColors lerp(ThemeExtension<KadjaneColors>? other, double t) {
    if (other is! KadjaneColors) {
      return this;
    }
    return KadjaneColors(
      brand: Color.lerp(brand, other.brand, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
      chartArea: Color.lerp(chartArea, other.chartArea, t)!,
      wheelColors: t < 0.5 ? wheelColors : other.wheelColors,
    );
  }
}
