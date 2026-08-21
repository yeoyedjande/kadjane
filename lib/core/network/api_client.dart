import 'package:kadjane/core/error/app_exception.dart';

/// Objet JSON renvoyé par l'API.
typedef JsonMap = Map<String, dynamic>;

/// Contrat d'accès HTTP au backend Kadjane.
///
/// Les repositories dépendent de cette interface, jamais d'un client HTTP
/// concret : le passage du mock au REST se fait par simple injection.
abstract interface class ApiClient {
  Future<JsonMap> get(String path, {Map<String, dynamic>? query});

  /// Variante pour les endpoints renvoyant un tableau JSON.
  Future<List<JsonMap>> getList(String path, {Map<String, dynamic>? query});

  Future<JsonMap> post(String path, {Object? body});

  Future<JsonMap> put(String path, {Object? body});

  Future<JsonMap> patch(String path, {Object? body});

  Future<void> delete(String path);
}

/// Routes de l'API (aucune URL en dur dans les repositories).
class ApiRoutes {
  const ApiRoutes._();

  // --- Authentification ---
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String requestOtp = '/auth/otp/request';
  static const String verifyOtp = '/auth/otp/verify';
  static const String resetPassword = '/auth/password/reset';
  static const String logout = '/auth/logout';
  static const String me = '/me';

  // --- Organisations ---
  static const String organizations = '/organizations';

  static String organization(String id) => '/organizations/$id';

  static String membership(String organizationId) =>
      '/organizations/$organizationId/membership';

  static String officers(String organizationId) =>
      '/organizations/$organizationId/officers';

  // --- Membres ---
  static String members(String organizationId) =>
      '/organizations/$organizationId/members';

  static String member(String memberId) => '/members/$memberId';

  static String memberStats(String memberId) => '/members/$memberId/stats';

  static String memberContributions(String organizationId, String memberId) =>
      '/organizations/$organizationId/members/$memberId/contributions';

  static String memberPayoutTotal(String organizationId, String memberId) =>
      '/organizations/$organizationId/members/$memberId/payouts/total';

  // --- Tontines ---
  static String tontines(String organizationId) =>
      '/organizations/$organizationId/tontines';

  static String tontine(String tontineId) => '/tontines/$tontineId';

  static String tontineSummary(String tontineId) =>
      '/tontines/$tontineId/summary';

  static String tontineStatus(String tontineId) =>
      '/tontines/$tontineId/status';

  static String participants(String tontineId) =>
      '/tontines/$tontineId/participants';

  static String participantsOrder(String tontineId) =>
      '/tontines/$tontineId/participants/order';

  static String cycles(String tontineId) => '/tontines/$tontineId/cycles';

  static String currentCycle(String tontineId) =>
      '/tontines/$tontineId/cycles/current';

  static String cycle(String cycleId) => '/cycles/$cycleId';

  // --- Cotisations ---
  static String cycleSlots(String cycleId) =>
      '/cycles/$cycleId/contribution-slots';

  static String cycleContributions(String cycleId) =>
      '/cycles/$cycleId/contributions';

  static String tontineContributions(String tontineId) =>
      '/tontines/$tontineId/contributions';

  static String confirmContribution(String contributionId) =>
      '/contributions/$contributionId/confirm';

  static String cancelContribution(String contributionId) =>
      '/contributions/$contributionId/cancel';

  // --- Tirages ---
  static String drawEligibility(String tontineId, String cycleId) =>
      '/tontines/$tontineId/cycles/$cycleId/draw-eligibility';

  static String draws(String tontineId) => '/tontines/$tontineId/draws';

  static String orderDraw(String tontineId) =>
      '/tontines/$tontineId/draws/order';

  static String draw(String drawId) => '/draws/$drawId';

  static String cycleDraw(String cycleId) => '/cycles/$cycleId/draw';

  static String cancelDraw(String drawId) => '/draws/$drawId/cancel';

  static String invalidateDraw(String drawId) => '/draws/$drawId/invalidate';

  // --- Bénéficiaires et versements ---
  static String beneficiaries(String tontineId) =>
      '/tontines/$tontineId/beneficiaries';

  static String cycleBeneficiary(String cycleId) =>
      '/cycles/$cycleId/beneficiary';

  static String beneficiary(String beneficiaryId) =>
      '/beneficiaries/$beneficiaryId';

  static String cyclePayout(String cycleId) => '/cycles/$cycleId/payout';

  static String payouts(String tontineId) => '/tontines/$tontineId/payouts';

  static const String createPayout = '/payouts';

  // --- Gouvernance : roles et relances ---
  static String roles(String organizationId) =>
      '/organizations/$organizationId/roles';

  static String role(String organizationId, String roleCode) =>
      '/organizations/$organizationId/roles/$roleCode';

  static String roleReset(String organizationId, String roleCode) =>
      '/organizations/$organizationId/roles/$roleCode/reset';

  static String reminderTargets(String organizationId) =>
      '/organizations/$organizationId/reminder-targets';

  static String cycleReminderTargets(String tontineId, String cycleId) =>
      '/tontines/$tontineId/cycles/$cycleId/reminder-targets';

  static const String reminderCampaigns = '/reminder-campaigns';

  static String organizationCampaigns(String organizationId) =>
      '/organizations/$organizationId/reminder-campaigns';

  static String memberReminders(String organizationId, String memberId) =>
      '/organizations/$organizationId/members/$memberId/reminders';

  static String cycleReminders(String cycleId) => '/cycles/$cycleId/reminders';

  static String reminderRead(String reminderId) =>
      '/reminders/$reminderId/read';

  // --- Transverse ---
  static const String notifications = '/notifications';

  static const String notificationsUnread = '/notifications/unread-count';

  static const String notificationsReadAll = '/notifications/read-all';

  static const String notificationDevices = '/notifications/devices';

  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';

  static String auditLogs(String organizationId) =>
      '/organizations/$organizationId/audit-logs';

  static String treasury(String organizationId) =>
      '/organizations/$organizationId/treasury';

  static String transactions(String organizationId) =>
      '/organizations/$organizationId/transactions';

  static String dashboard(String organizationId) =>
      '/organizations/$organizationId/dashboard';

  static String reports(String organizationId) =>
      '/organizations/$organizationId/reports';

  static String reportsExport(String organizationId) =>
      '/organizations/$organizationId/reports/export';
}

/// Client par défaut lorsqu'aucun backend n'est configuré.
///
/// Il n'est utilisé que si l'application est lancée en mode REST sans URL
/// valide : l'erreur est alors explicite plutôt que silencieuse.
class NotConfiguredApiClient implements ApiClient {
  const NotConfiguredApiClient();

  Never _fail(String path) =>
      throw ServerException('api_not_configured:$path', 501);

  @override
  Future<JsonMap> get(String path, {Map<String, dynamic>? query}) async =>
      _fail(path);

  @override
  Future<List<JsonMap>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async => _fail(path);

  @override
  Future<JsonMap> post(String path, {Object? body}) async => _fail(path);

  @override
  Future<JsonMap> put(String path, {Object? body}) async => _fail(path);

  @override
  Future<JsonMap> patch(String path, {Object? body}) async => _fail(path);

  @override
  Future<void> delete(String path) async => _fail(path);
}
