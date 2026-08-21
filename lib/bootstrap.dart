import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/app.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/utils/logger.dart';

/// Démarrage de l'application : configuration, stockage, préférences.
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize(config);

  const AppLogger logger = AppLogger('bootstrap');
  logger.info('Démarrage Kadjane (${config.environment.code})');

  KeyValueStore store;
  try {
    store = await SharedPreferencesStore.create();
  } on Exception catch (error, stackTrace) {
    // Le stockage local ne doit jamais empêcher l'application de démarrer.
    logger.error('Stockage des préférences indisponible', error, stackTrace);
    store = InMemoryKeyValueStore();
  }

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  await container.read(appSettingsProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(container: container, child: const KadjaneApp()),
  );
}
