import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/admin/router/admin_router.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/design_system/theme/app_theme.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

/// Racine de la console d'administration Kadjane (Flutter Web).
///
/// Elle partage le domaine, les repositories, le design system et les
/// traductions de l'application mobile : seule la couche présentation diffère.
class KadjaneAdminApp extends ConsumerWidget {
  const KadjaneAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final GoRouter router = ref.watch(adminRouterProvider);

    return MaterialApp.router(
      title: 'Kadjane Admin',
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
    );
  }
}
