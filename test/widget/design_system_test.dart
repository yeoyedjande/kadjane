import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_colors.dart';
import 'package:kadjane/design_system/theme/app_theme.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_progress.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.light,
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('KBadge affiche son libellé avec le ton demandé', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KBadge(
          label: 'Payé',
          tone: StatusTone(
            KadjaneColors.light.success,
            KadjaneColors.light.successSurface,
          ),
        ),
      ),
    );

    expect(find.text('Payé'), findsOneWidget);
  });

  testWidgets('KAmountProgress affiche montants et pourcentage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 320,
          child: KAmountProgress(
            collected: 850000,
            expected: 1000000,
            currency: Currency.xof,
          ),
        ),
      ),
    );

    expect(find.text('850 000 / 1 000 000 FCFA'), findsOneWidget);
    expect(find.text('85 %'), findsOneWidget);
  });

  testWidgets('KButton affiche un indicateur pendant le chargement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(KButton(label: 'Enregistrer', isLoading: true, onPressed: () {})),
    );

    expect(find.text('Enregistrer'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('KEmptyState propose une action de secours', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KEmptyState(
          message: 'Aucune tontine pour le moment',
          actionLabel: 'Créer une tontine',
          onAction: () {},
        ),
      ),
    );

    expect(find.text('Aucune tontine pour le moment'), findsOneWidget);
    expect(find.text('Créer une tontine'), findsOneWidget);
    expect(find.text('Rien à afficher'), findsOneWidget);
  });

  testWidgets('KErrorState traduit l\'erreur et propose de réessayer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(KErrorState(error: Exception('boom'), onRetry: () {})),
    );

    expect(find.text('Une erreur est survenue'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('le thème sombre expose les mêmes jetons de couleur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const Text('Kadjane'), theme: AppTheme.dark));

    final BuildContext context = tester.element(find.text('Kadjane'));
    final KadjaneColors? colors = Theme.of(context).extension<KadjaneColors>();

    expect(colors, isNotNull);
    expect(colors!.success, isNot(KadjaneColors.light.success));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
