/// Chemins de la console d'administration.
class AdminRoutes {
  const AdminRoutes._();

  static const String login = '/login';
  static const String overview = '/';
  static const String members = '/membres';
  static const String roles = '/roles';
  static const String reminders = '/relances';
  static const String tontines = '/tontines';
  static const String audit = '/audit';
  static const String settings = '/parametres';

  static const Set<String> publicRoutes = <String>{login};
}
