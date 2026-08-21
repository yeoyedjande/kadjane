import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/admin/admin_app.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/storage/key_value_store.dart';

/// Point d'entrée de la console web d'administration.
///
///   flutter run -d chrome -t lib/main_admin.dart
///   flutter build web -t lib/main_admin.dart --output build/admin
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize(AppConfig.fromDartDefine());

  KeyValueStore store;
  try {
    store = await SharedPreferencesStore.create();
  } on Exception {
    store = InMemoryKeyValueStore();
  }

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  await container.read(appSettingsProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const KadjaneAdminApp(),
    ),
  );
}
