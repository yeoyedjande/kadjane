import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/core/storage/key_value_store.dart';

/// Préférences d'affichage persistées (thème, langue, onboarding).
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('fr'),
    this.onboardingSeen = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool onboardingSeen;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? onboardingSeen,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
  );
}

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  /// Charge les préférences au démarrage (appelé depuis le bootstrap).
  Future<void> load() async {
    final String? theme = await _store.getString(StorageKeys.themeMode);
    final String? locale = await _store.getString(StorageKeys.locale);
    final bool seen = await _store.getBool(StorageKeys.onboardingSeen) ?? false;
    state = AppSettings(
      themeMode: _themeFromCode(theme),
      locale: Locale(locale ?? 'fr'),
      onboardingSeen: seen,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.setString(StorageKeys.themeMode, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _store.setString(StorageKeys.locale, locale.languageCode);
  }

  Future<void> markOnboardingSeen() async {
    state = state.copyWith(onboardingSeen: true);
    await _store.setBool(StorageKeys.onboardingSeen, true);
  }

  static ThemeMode _themeFromCode(String? code) {
    switch (code) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final NotifierProvider<AppSettingsController, AppSettings> appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
