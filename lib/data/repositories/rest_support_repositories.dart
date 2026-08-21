import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/activity_dto.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/cash_transaction.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/repositories/notification_repository.dart';
import 'package:kadjane/domain/repositories/report_repository.dart';
import 'package:kadjane/domain/repositories/treasury_repository.dart';

/// Repositories REST transverses : audit, notifications, caisse, dashboard,
/// rapports. Regroupés ici car chacun tient en quelques appels.

class RestAuditRepository implements AuditRepository {
  const RestAuditRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AuditLog>> list({
    required String organizationId,
    String? tontineId,
    Set<AuditAction>? actions,
    int limit = 100,
  }) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.auditLogs(organizationId),
      query: <String, dynamic>{
        'tontineId': ?tontineId,
        if (actions != null)
          'actions': actions.map((AuditAction a) => a.code).toList(),
        'limit': limit,
      },
    );
    return response.map(AuditLogDto.fromJson).toList(growable: false);
  }

  @override
  Future<AuditLog> record({
    required String organizationId,
    required AuditAction action,
    required String description,
    String? actorMemberId,
    String? actorName,
    String? targetType,
    String? targetId,
    String? tontineId,
    double? amount,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async => AuditLogDto.fromJson(
    await _api.post(
      ApiRoutes.auditLogs(organizationId),
      body: <String, dynamic>{
        'action': action.code,
        'description': description,
        'actorMemberId': actorMemberId,
        'actorName': actorName,
        'targetType': targetType,
        'targetId': targetId,
        'tontineId': tontineId,
        'amount': amount,
        'metadata': metadata,
      },
    ),
  );
}

class RestNotificationRepository implements NotificationRepository {
  const RestNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AppNotification>> list({
    required String userId,
    String? organizationId,
  }) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.notifications,
      query: <String, dynamic>{
        'userId': userId,
        'organizationId': ?organizationId,
      },
    );
    return response.map(AppNotificationDto.fromJson).toList(growable: false);
  }

  @override
  Future<int> unreadCount({
    required String userId,
    String? organizationId,
  }) async {
    final JsonMap response = await _api.get(
      ApiRoutes.notificationsUnread,
      query: <String, dynamic>{
        'userId': userId,
        'organizationId': ?organizationId,
      },
    );
    return Json.integer(response, 'count');
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _api.post(ApiRoutes.notificationRead(notificationId));
  }

  @override
  Future<void> markAllAsRead({
    required String userId,
    String? organizationId,
  }) async {
    await _api.post(
      ApiRoutes.notificationsReadAll,
      body: <String, dynamic>{
        'userId': userId,
        'organizationId': organizationId,
      },
    );
  }

  @override
  Future<void> registerDeviceToken(String token) async {
    await _api.post(
      ApiRoutes.notificationDevices,
      body: <String, dynamic>{'token': token, 'platform': 'flutter'},
    );
  }
}

class RestTreasuryRepository implements TreasuryRepository {
  const RestTreasuryRepository(this._api);

  final ApiClient _api;

  @override
  Future<TreasurySnapshot> snapshot(String organizationId) async =>
      TreasurySnapshotDto.fromJson(
        await _api.get(ApiRoutes.treasury(organizationId)),
      );

  @override
  Future<CashTransaction> record({
    required String organizationId,
    required TransactionDraft draft,
    required String actorMemberId,
  }) async => CashTransactionDto.fromJson(
    await _api.post(
      ApiRoutes.transactions(organizationId),
      body: <String, dynamic>{
        ...CashTransactionDto.draftToJson(draft),
        'actorMemberId': actorMemberId,
      },
    ),
  );
}

class RestDashboardRepository implements DashboardRepository {
  const RestDashboardRepository(this._api);

  final ApiClient _api;

  @override
  Future<DashboardSnapshot> load({
    required String organizationId,
    required String memberId,
  }) async => DashboardSnapshotDto.fromJson(
    await _api.get(
      ApiRoutes.dashboard(organizationId),
      query: <String, dynamic>{'memberId': memberId},
    ),
  );
}

class RestReportRepository implements ReportRepository {
  const RestReportRepository(this._api);

  final ApiClient _api;

  @override
  Future<ReportSnapshot> load(String organizationId) async =>
      ReportSnapshotDto.fromJson(
        await _api.get(ApiRoutes.reports(organizationId)),
      );

  @override
  Future<String> export({
    required String organizationId,
    required ReportFormat format,
  }) async {
    final JsonMap response = await _api.post(
      ApiRoutes.reportsExport(organizationId),
      body: <String, dynamic>{'format': format.name},
    );
    return Json.stringOr(response, 'url');
  }
}
