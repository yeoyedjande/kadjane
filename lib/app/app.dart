import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_router.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/theme/app_theme.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

/// Racine de l'application Kadjane.
class KadjaneApp extends ConsumerWidget {
  const KadjaneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kadjane',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        // Limite la largeur du contenu sur tablette/desktop et bride la mise à
        // l'échelle du texte pour préserver la mise en page.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

/// Largeur maximale de contenu utilisée par les écrans en mode large.
double contentWidthOf(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  return width > KSizes.tabletBreakpoint ? KSizes.contentMaxWidth : width;
}
