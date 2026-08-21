import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/admin/admin_app.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';

/// Parcours de la console web d'administration.
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

  Widget buildConsole() => ProviderScope(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: const KadjaneAdminApp(),
  );

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// La console vise le poste de travail : on simule un grand écran.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.pumpWidget(buildConsole());
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Connexion'));
    await settle(tester);
  }

  testWidgets('exige une connexion avant d\'ouvrir la console', (
    WidgetTester tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(buildConsole());
    await settle(tester);

    expect(find.text('Connexion'), findsWidgets);
    expect(find.text('Vue d\'ensemble'), findsNothing);
  });

  testWidgets('affiche la navigation et le pilotage après connexion', (
    WidgetTester tester,
  ) async {
    useDesktopSurface(tester);
    await signIn(tester);

    expect(find.text('Console d\'administration'), findsOneWidget);
    expect(find.text('Vue d\'ensemble'), findsWidgets);
    expect(find.text('Rôles et permissions'), findsOneWidget);
    expect(find.text('Relances'), findsWidgets);
    expect(find.text('Association Solidarité'), findsWidgets);
    expect(find.text('Taux de recouvrement'), findsOneWidget);
  });

  testWidgets('la matrice des permissions liste les rôles et les droits', (
    WidgetTester tester,
  ) async {
    useDesktopSurface(tester);
    await signIn(tester);

    await tester.tap(find.text('Rôles et permissions'));
    await settle(tester);

    expect(find.text('Matrice des permissions'), findsOneWidget);
    expect(find.text('Trésorier'), findsWidgets);
    expect(find.text('Commissaire aux comptes'), findsWidgets);
    // Une ligne de module et ses actions.
    expect(find.text('Cotisations'), findsWidgets);
    expect(find.byType(Checkbox), findsWidgets);
  });

  testWidgets('le centre de relance liste les impayés à relancer', (
    WidgetTester tester,
  ) async {
    useDesktopSurface(tester);
    await signIn(tester);

    await tester.tap(find.text('Relances').first);
    await settle(tester);

    expect(find.text('Centre de relance'), findsOneWidget);
    expect(find.text('À relancer'), findsWidgets);
    expect(find.textContaining('OUATTARA'), findsWidgets);
    expect(find.text('Envoyer les relances'), findsWidgets);
  });
}
