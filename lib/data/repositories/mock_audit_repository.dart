import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';

/// Journal d'audit en mémoire (écriture seule, jamais de suppression).
///
/// TODO(api): remplacer par `RestAuditRepository` (/organizations/{id}/audit-logs).
class MockAuditRepository implements AuditRepository {
  MockAuditRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<AuditLog>> list({
    required String organizationId,
    String? tontineId,
    Set<AuditAction>? actions,
    int limit = 100,
  }) => _db.withLatency(() {
    final List<AuditLog> logs = _db.auditLogs
        .where(
          (AuditLog log) =>
              log.organizationId == organizationId &&
              (tontineId == null || log.tontineId == tontineId) &&
              (actions == null || actions.contains(log.action)),
        )
        .toList();
    logs.sort((AuditLog a, AuditLog b) => b.createdAt.compareTo(a.createdAt));
    return logs.take(limit).toList(growable: false);
  });

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
  }) async {
    final AuditLog log = AuditLog(
      id: _db.nextId('adt'),
      organizationId: organizationId,
      action: action,
      description: description,
      actorMemberId: actorMemberId,
      actorName: actorName ?? _actorName(actorMemberId),
      targetType: targetType,
      targetId: targetId,
      tontineId: tontineId,
      amount: amount,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
    _db.auditLogs.add(log);
    return log;
  }

  String _actorName(String? memberId) {
    if (memberId == null) {
      return 'Système';
    }
    try {
      return _db.memberById(memberId).fullName;
    } on Object {
      return 'Système';
    }
  }
}
