import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/features/activity/presentation/screens/activity_screen.dart';
import 'package:kadjane/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:kadjane/features/auth/presentation/screens/login_screen.dart';
import 'package:kadjane/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:kadjane/features/auth/presentation/screens/otp_screen.dart';
import 'package:kadjane/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:kadjane/features/auth/presentation/screens/splash_screen.dart';
import 'package:kadjane/features/beneficiary/presentation/screens/beneficiary_screen.dart';
import 'package:kadjane/features/contributions/presentation/screens/contributions_screen.dart';
import 'package:kadjane/features/contributions/presentation/screens/cycle_contributions_screen.dart';
import 'package:kadjane/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:kadjane/features/draw/presentation/screens/draw_screen.dart';
import 'package:kadjane/features/members/presentation/screens/member_detail_screen.dart';
import 'package:kadjane/features/members/presentation/screens/member_form_screen.dart';
import 'package:kadjane/features/members/presentation/screens/members_screen.dart';
import 'package:kadjane/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:kadjane/features/organization/presentation/screens/organization_settings_screen.dart';
import 'package:kadjane/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:kadjane/features/profile/presentation/screens/profile_screen.dart';
import 'package:kadjane/features/reports/presentation/screens/reports_screen.dart';
import 'package:kadjane/features/shell/presentation/app_shell.dart';
import 'package:kadjane/features/tontines/presentation/screens/tontine_detail_screen.dart';
import 'package:kadjane/features/tontines/presentation/screens/tontine_wizard_screen.dart';
import 'package:kadjane/features/tontines/presentation/screens/tontines_screen.dart';
import 'package:kadjane/features/treasury/presentation/screens/treasury_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Routeur de l'application.
///
/// La redirection gère : onboarding, session absente/expirée et retour
/// automatique vers l'accueil une fois connecté.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);
  ref
    ..listen(authControllerProvider, (_, _) => refreshSignal.value++)
    ..listen(appSettingsProvider, (_, _) => refreshSignal.value++)
    ..onDispose(refreshSignal.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshSignal,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<Object?> auth = ref.read(authControllerProvider);
      final String location = state.matchedLocation;

      // Session en cours de restauration : on reste sur le splash.
      if (auth.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final bool isAuthenticated = auth.valueOrNull != null;
      final bool onboardingSeen = ref.read(appSettingsProvider).onboardingSeen;
      final bool isPublic = AppRoutes.publicRoutes.contains(location);

      if (!isAuthenticated) {
        if (!onboardingSeen && location != AppRoutes.onboarding) {
          return AppRoutes.onboarding;
        }
        if (location == AppRoutes.splash) {
          return onboardingSeen ? AppRoutes.login : AppRoutes.onboarding;
        }
        return isPublic ? null : AppRoutes.login;
      }

      if (isPublic) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      // Pas d'inscription libre : les comptes sont créés par l'administrateur
      // depuis le back-office, et le membre définit son mot de passe à la
      // première connexion (« Mot de passe oublié ? », par OTP).
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (BuildContext context, GoRouterState state) =>
            OtpScreen(target: state.uri.queryParameters['target'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (BuildContext context, GoRouterState state) =>
            ResetPasswordScreen(
              resetToken: state.uri.queryParameters['token'] ?? '',
            ),
      ),

      // Coquille principale : 5 onglets, état conservé par onglet.
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell shell,
            ) => AppShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.tontines,
                builder: (_, _) => const TontinesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.contributions,
                builder: (_, _) => const ContributionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.activity,
                builder: (_, _) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.tontineCreate,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const TontineWizardScreen(),
      ),
      GoRoute(
        path: AppRoutes.tontineDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            TontineDetailScreen(tontineId: state.pathParameters['tontineId']!),
      ),
      GoRoute(
        path: AppRoutes.tontineDrawPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) => DrawScreen(
          tontineId: state.pathParameters['tontineId']!,
          cycleId: state.pathParameters['cycleId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.tontineCyclePattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            CycleContributionsScreen(
              tontineId: state.pathParameters['tontineId']!,
              cycleId: state.pathParameters['cycleId']!,
            ),
      ),
      GoRoute(
        path: AppRoutes.tontineBeneficiaryPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            BeneficiaryScreen(
              tontineId: state.pathParameters['tontineId']!,
              cycleId: state.pathParameters['cycleId']!,
            ),
      ),
      GoRoute(
        path: AppRoutes.members,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const MembersScreen(),
      ),
      GoRoute(
        path: AppRoutes.memberCreate,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const MemberFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.memberDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            MemberDetailScreen(memberId: state.pathParameters['memberId']!),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.treasury,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const TreasuryScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.organizationSettings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const OrganizationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const EditProfileScreen(),
      ),
    ],
  );
});
