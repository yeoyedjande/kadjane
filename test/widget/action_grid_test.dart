import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/design_system/theme/app_theme.dart';
import 'package:kadjane/design_system/widgets/k_action_grid.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

/// Disposition des raccourcis du tableau de bord.
///
/// Régression : les tuiles avaient une largeur fixe de 104 px. Sur téléphone,
/// elles laissaient un bord droit irrégulier et ne remplissaient pas la ligne.
void main() {
  List<KAction> actions() => <KAction>[
    KAction(icon: Icons.groups_2_outlined, label: 'Membres', onTap: () {}),
    KAction(icon: Icons.savings_outlined, label: 'Cotisations', onTap: () {}),
    KAction(icon: Icons.insert_chart_outlined, label: 'Rapports', onTap: () {}),
    KAction(
      icon: Icons.settings_outlined,
      label: "Paramètres de l'organisation",
      onTap: () {},
    ),
  ];

  Widget wrap(double width) => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(width: width, child: KActionGrid(actions: actions())),
    ),
  );

  List<Size> tileSizes(WidgetTester tester) => tester
      .widgetList<SizedBox>(
        find.descendant(
          of: find.byType(KActionGrid),
          matching: find.byType(SizedBox),
        ),
      )
      .where((SizedBox box) => box.height == KActionGrid.tileHeight)
      .map((SizedBox box) => Size(box.width!, box.height!))
      .toList();

  testWidgets('deux colonnes sur téléphone, de largeur égale', (
    WidgetTester tester,
  ) async {
    const double screen = 375; // iPhone SE / téléphone Android courant
    await tester.pumpWidget(wrap(screen));

    final List<Size> sizes = tileSizes(tester);
    expect(sizes.length, 4);
    expect(sizes.map((Size s) => s.width).toSet().length, 1);

    // Deux tuiles plus l'espace entre elles remplissent exactement la ligne.
    expect(sizes.first.width * 2, lessThan(screen));
    expect(sizes.first.width * 2, greaterThan(screen * 0.9));
  });

  testWidgets('quatre colonnes au-delà du point de rupture', (
    WidgetTester tester,
  ) async {
    // La surface de test fait 800 px : rester en deçà pour que la largeur
    // demandée ne soit pas contrainte.
    const double wide = 720;
    await tester.pumpWidget(wrap(wide));

    final List<Size> sizes = tileSizes(tester);
    expect(sizes.map((Size s) => s.width).toSet().length, 1);
    expect(sizes.first.width * 4, lessThan(wide));
    expect(sizes.first.width * 4, greaterThan(wide * 0.9));
  });

  testWidgets('toutes les tuiles ont la même hauteur, libellé long compris', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(375));

    final Set<double> heights = tileSizes(
      tester,
    ).map((Size s) => s.height).toSet();
    expect(heights.length, 1);
  });

  test('la règle de colonnes suit la largeur', () {
    expect(KActionGrid.columnsFor(360), 2);
    expect(KActionGrid.columnsFor(599), 2);
    expect(KActionGrid.columnsFor(600), 4);
    expect(KActionGrid.columnsFor(1200), 4);
  });
}
