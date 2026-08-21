import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/admin/router/admin_routes.dart';
import 'package:kadjane/admin/screens/admin_audit_screen.dart';
import 'package:kadjane/admin/screens/admin_members_screen.dart';
import 'package:kadjane/admin/screens/admin_overview_screen.dart';
import 'package:kadjane/admin/screens/admin_reminders_screen.dart';
import 'package:kadjane/admin/screens/admin_roles_screen.dart';
import 'package:kadjane/admin/screens/admin_settings_screen.dart';
import 'package:kadjane/admin/screens/admin_tontines_screen.dart';
import 'package:kadjane/admin/shell/admin_shell.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/features/auth/presentation/screens/login_screen.dart';
import 'package:kadjane/features/auth/presentation/screens/splash_screen.dart';

/// Routeur de la console d'administration.
///
/// La connexion réutilise l'écran de l'application mobile : mêmes comptes,
/// même session sécurisée.
final Provider<GoRouter> adminRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);
  ref
    ..listen(authControllerProvider, (_, _) => refreshSignal.value++)
    ..onDispose(refreshSignal.dispose);

  return GoRouter(
    initialLocation: AdminRoutes.overview,
    refreshListenable: refreshSignal,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<Object?> auth = ref.read(authControllerProvider);
      final String location = state.matchedLocation;
      if (auth.isLoading) {
        return null;
      }
      final bool isAuthenticated = auth.valueOrNull != null;
      final bool isPublic = AdminRoutes.publicRoutes.contains(location);
      if (!isAuthenticated) {
        return isPublic ? null : AdminRoutes.login;
      }
      return isPublic ? AdminRoutes.overview : null;
    },
    routes: <RouteBase>[
      GoRoute(path: AdminRoutes.login, builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AdminShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AdminRoutes.overview,
            builder: (_, _) => const AdminOverviewScreen(),
          ),
          GoRoute(
            path: AdminRoutes.members,
            builder: (_, _) => const AdminMembersScreen(),
          ),
          GoRoute(
            path: AdminRoutes.roles,
            builder: (_, _) => const AdminRolesScreen(),
          ),
          GoRoute(
            path: AdminRoutes.reminders,
            builder: (_, _) => const AdminRemindersScreen(),
          ),
          GoRoute(
            path: AdminRoutes.tontines,
            builder: (_, _) => const AdminTontinesScreen(),
          ),
          GoRoute(
            path: AdminRoutes.audit,
            builder: (_, _) => const AdminAuditScreen(),
          ),
          GoRoute(
            path: AdminRoutes.settings,
            builder: (_, _) => const AdminSettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, _) => const SplashScreen(),
  );
});
