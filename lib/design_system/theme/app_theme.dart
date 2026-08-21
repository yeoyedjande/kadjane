import 'package:flutter/material.dart';
import 'package:kadjane/design_system/theme/app_colors.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/theme/app_typography.dart';

/// Thèmes clair et sombre de Kadjane.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    colors: KadjaneColors.light,
    scheme: const ColorScheme.light(
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      primaryContainer: AppPalette.primaryContainer,
      onPrimaryContainer: AppPalette.green900,
      secondary: AppPalette.gold,
      onSecondary: Color(0xFF3B2E14),
      secondaryContainer: AppPalette.goldContainer,
      onSecondaryContainer: Color(0xFF3B2E14),
      tertiary: AppPalette.terracotta,
      onTertiary: Colors.white,
      tertiaryContainer: AppPalette.terracottaContainer,
      onTertiaryContainer: Color(0xFF4A1C0D),
      surface: AppPalette.surface,
      onSurface: AppPalette.textPrimary,
      surfaceContainerHighest: AppPalette.surfaceMuted,
      onSurfaceVariant: AppPalette.textSecondary,
      outline: AppPalette.outline,
      outlineVariant: AppPalette.outline,
      error: AppPalette.danger,
      onError: Colors.white,
    ),
    scaffoldBackground: AppPalette.background,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    colors: KadjaneColors.dark,
    scheme: const ColorScheme.dark(
      primary: AppPalette.primaryLight,
      onPrimary: Color(0xFF04231B),
      primaryContainer: Color(0xFF12463A),
      onPrimaryContainer: Color(0xFFB9EBDA),
      secondary: AppPalette.gold,
      onSecondary: Color(0xFF2A2109),
      secondaryContainer: Color(0xFF3B2E14),
      onSecondaryContainer: Color(0xFFF6E2C0),
      tertiary: Color(0xFFE07A55),
      onTertiary: Color(0xFF3A1305),
      tertiaryContainer: Color(0xFF4A1C0D),
      onTertiaryContainer: Color(0xFFF8DFD6),
      surface: AppPalette.surfaceDark,
      onSurface: AppPalette.textPrimaryDark,
      surfaceContainerHighest: AppPalette.surfaceMutedDark,
      onSurfaceVariant: AppPalette.textSecondaryDark,
      outline: AppPalette.outlineDark,
      outlineVariant: AppPalette.outlineDark,
      error: AppPalette.dangerDark,
      onError: Color(0xFF3A1D1A),
    ),
    scaffoldBackground: AppPalette.backgroundDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required KadjaneColors colors,
    required ColorScheme scheme,
    required Color scaffoldBackground,
  }) {
    final TextTheme textTheme = AppTypography.textTheme(
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: KRadius.card,
          side: BorderSide(color: colors.divider),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: KRadius.field,
          borderSide: BorderSide(color: colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KRadius.field,
          borderSide: BorderSide(color: colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: KRadius.field,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: KRadius.field,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: KRadius.field,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
        labelStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(KSizes.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: KRadius.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(KSizes.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: KRadius.button),
          side: BorderSide(color: colors.divider),
          foregroundColor: colors.textPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceMuted,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: colors.divider),
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: KRadius.badge),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: colors.textTertiary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 0.1,
                )
              : textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  letterSpacing: 0.1,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) => IconThemeData(
            size: KSizes.iconMd,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : colors.textTertiary,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KRadius.xl)),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: KRadius.sheet),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.surface),
        shape: const RoundedRectangleBorder(borderRadius: KRadius.field),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: colors.textTertiary,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: colors.divider,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: colors.surfaceMuted,
        circularTrackColor: colors.surfaceMuted,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: colors.textSecondary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
    );
  }
}
