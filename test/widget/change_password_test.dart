import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/domain/repositories/auth_repository.dart';
import 'package:kadjane/features/profile/presentation/screens/change_password_screen.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

/// Enregistre l'appel au lieu de le jouer : seul le contrat compte ici.
class _RecordingAuthRepository implements AuthRepository {
  String? currentPassword;
  String? newPassword;
  Object? failure;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
    if (failure != null) {
      throw failure!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} hors du périmètre');
}

void main() {
  late _RecordingAuthRepository repository;

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
    repository = _RecordingAuthRepository();
  });

  Widget buildScreen() => ProviderScope(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      authRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangePasswordScreen(),
    ),
  );

  Future<void> fill(
    WidgetTester tester, {
    required String current,
    required String password,
    required String confirm,
  }) async {
    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), password);
    await tester.enterText(fields.at(2), confirm);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('transmet l\'ancien et le nouveau mot de passe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await fill(
      tester,
      current: 'Provisoire1',
      password: 'MonNouveauMotDePasse1',
      confirm: 'MonNouveauMotDePasse1',
    );

    await submit(tester);

    expect(repository.currentPassword, 'Provisoire1');
    expect(repository.newPassword, 'MonNouveauMotDePasse1');
  });

  testWidgets('refuse une confirmation qui ne correspond pas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await fill(
      tester,
      current: 'Provisoire1',
      password: 'MonNouveauMotDePasse1',
      confirm: 'AutreChose1',
    );

    await submit(tester);

    expect(repository.newPassword, isNull);
    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });

  testWidgets('refuse un mot de passe trop court', (WidgetTester tester) async {
    await tester.pumpWidget(buildScreen());
    await fill(tester, current: 'Provisoire1', password: 'court', confirm: 'court');

    await submit(tester);

    expect(repository.newPassword, isNull);
    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères'),
      findsOneWidget,
    );
  });

  testWidgets('exige le mot de passe actuel', (WidgetTester tester) async {
    await tester.pumpWidget(buildScreen());
    await fill(
      tester,
      current: '',
      password: 'MonNouveauMotDePasse1',
      confirm: 'MonNouveauMotDePasse1',
    );

    await submit(tester);

    expect(repository.currentPassword, isNull);
  });
}
