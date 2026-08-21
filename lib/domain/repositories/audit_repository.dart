import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/enums/audit_action.dart';

/// Journal d'audit en écriture seule.
abstract interface class AuditRepository {
  Future<List<AuditLog>> list({
    required String organizationId,
    String? tontineId,
    Set<AuditAction>? actions,
    int limit = 100,
  });

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
  });
}
