import 'package:flutter/material.dart';
import 'package:kadjane/design_system/theme/app_colors.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

/// Raccourcis de contexte utilisés dans toute la couche présentation.
extension KadjaneContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  ThemeData get theme => Theme.of(this);

  TextTheme get text => Theme.of(this).textTheme;

  ColorScheme get scheme => Theme.of(this).colorScheme;

  /// Couleurs sémantiques Kadjane (succès, alerte, texte secondaire...).
  KadjaneColors get colors =>
      Theme.of(this).extension<KadjaneColors>() ?? KadjaneColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Code de langue courant (`fr` ou `en`), utilisé par les formateurs.
  String get localeCode => Localizations.localeOf(this).languageCode;

  bool get isWide => MediaQuery.sizeOf(this).width >= KSizes.tabletBreakpoint;

  /// Affiche un message court (succès ou erreur) en bas d'écran.
  void showMessage(String message, {bool isError = false}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? colors.danger : colors.success,
                size: KSizes.iconSm,
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
