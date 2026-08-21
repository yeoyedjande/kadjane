import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/app/app.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';

/// Parcours de bout en bout sur les données de démonstration.
void main() {
  setUp(() {
    AppConfig.initialize(
      const AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: 'https://api.test.kadjane.app/v1',
        useMockData: true,
        networkLatency: Duration.zero,
        enableVerboseLogs: false,
      ),
    );
  });

  Widget buildApp() => ProviderScope(
    overrides: <Override>[
      // Le stockage sécurisé et les préférences passent par des plugins
      // natifs : on injecte des implémentations mémoire pour les tests.
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: const KadjaneApp(),
  );

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('affiche l\'onboarding au premier lancement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('Gérez votre tontine simplement'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
  });

  testWidgets('connexion puis accès au tableau de bord', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    // Onboarding -> connexion
    await tester.tap(find.text('Passer'));
    await settle(tester);
    expect(find.text('Connexion'), findsWidgets);

    // Les identifiants de démonstration sont pré-remplis.
    await tester.tap(find.widgetWithText(FilledButton, 'Connexion'));
    await settle(tester);

    // Tableau de bord de l'organisation active.
    expect(find.textContaining('Bonjour'), findsOneWidget);
    expect(find.text('Association Solidarité'), findsOneWidget);
    expect(find.text('Progression de la collecte'), findsOneWidget);
  });

  testWidgets('la navigation par onglets atteint les tontines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);
    await tester.tap(find.text('Passer'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Connexion'));
    await settle(tester);

    await tester.tap(find.text('Tontines').last);
    await settle(tester);

    expect(find.text('Mes tontines'), findsOneWidget);
    expect(find.text('Tontine Solidarité'), findsOneWidget);
  });
}
