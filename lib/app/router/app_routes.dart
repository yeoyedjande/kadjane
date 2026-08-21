/// Chemins de navigation centralisés.
///
/// Aucun écran n'écrit une route en dur : on passe toujours par ces
/// constantes ou par les helpers ci-dessous.
class AppRoutes {
  const AppRoutes._();

  // Authentification
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String otp = '/otp';
  static const String resetPassword = '/reset-password';

  // Onglets principaux
  static const String home = '/home';
  static const String tontines = '/tontines';
  static const String contributions = '/contributions';
  static const String activity = '/activity';
  static const String profile = '/profile';

  // Tontines
  static const String tontineCreate = '/tontine-new';
  static const String tontineDetailPattern = '/tontine/:tontineId';
  static const String tontineDrawPattern = '/tontine/:tontineId/draw/:cycleId';
  static const String tontineCyclePattern =
      '/tontine/:tontineId/cycle/:cycleId';
  static const String tontineBeneficiaryPattern =
      '/tontine/:tontineId/beneficiary/:cycleId';

  static String tontineDetail(String tontineId) => '/tontine/$tontineId';

  static String tontineDraw(String tontineId, String cycleId) =>
      '/tontine/$tontineId/draw/$cycleId';

  static String tontineCycle(String tontineId, String cycleId) =>
      '/tontine/$tontineId/cycle/$cycleId';

  static String tontineBeneficiary(String tontineId, String cycleId) =>
      '/tontine/$tontineId/beneficiary/$cycleId';

  // Membres
  static const String members = '/members';
  static const String memberCreate = '/member-new';
  static const String memberDetailPattern = '/member/:memberId';

  static String memberDetail(String memberId) => '/member/$memberId';

  // Divers
  static const String notifications = '/notifications';
  static const String treasury = '/treasury';
  static const String reports = '/reports';
  static const String organizationSettings = '/organization';
  static const String profileEdit = '/profile-edit';

  /// Routes accessibles sans être connecté.
  static const Set<String> publicRoutes = <String>{
    splash,
    onboarding,
    login,
    register,
    forgotPassword,
    otp,
    resetPassword,
  };
}
