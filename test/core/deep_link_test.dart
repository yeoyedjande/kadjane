import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/app/router/app_routes.dart';

/// Destination des notifications.
///
/// Le chemin est produit par le backend : le client ne doit jamais le suivre
/// aveuglément. Une route obsolète déposerait l'utilisateur sur la page
/// d'erreur de go_router, et une route publique le sortirait de sa session.
void main() {
  group('résolution du lien profond', () {
    test('accepte une route fixe de l\'espace connecté', () {
      expect(AppRoutes.resolveDeepLink('/my-dues'), '/my-dues');
      expect(AppRoutes.resolveDeepLink('/notifications'), '/notifications');
    });

    test('accepte les routes paramétrées des tontines et des membres', () {
      expect(AppRoutes.resolveDeepLink('/tontine/abc'), '/tontine/abc');
      expect(
        AppRoutes.resolveDeepLink('/tontine/abc/cycle/42'),
        '/tontine/abc/cycle/42',
      );
      expect(AppRoutes.resolveDeepLink('/member/xyz'), '/member/xyz');
    });

    test('refuse une route inconnue du routeur', () {
      // Régression : le backend émettait `/tontines/<id>` au pluriel, quand
      // l'écran de détail est servi par `/tontine/<id>`.
      expect(AppRoutes.resolveDeepLink('/tontines/abc'), isNull);
      expect(AppRoutes.resolveDeepLink('/tontine/abc/inconnu/42'), isNull);
    });

    test('refuse une route publique, qui romprait la session', () {
      expect(AppRoutes.resolveDeepLink('/login'), isNull);
      expect(AppRoutes.resolveDeepLink('/'), isNull);
    });

    test('refuse une valeur vide, absente ou relative', () {
      expect(AppRoutes.resolveDeepLink(null), isNull);
      expect(AppRoutes.resolveDeepLink('   '), isNull);
      expect(AppRoutes.resolveDeepLink('my-dues'), isNull);
      expect(AppRoutes.resolveDeepLink('https://exemple.test/my-dues'), isNull);
    });
  });
}
