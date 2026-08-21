import 'package:kadjane/domain/enums/audit_action.dart';

/// Entrée du journal d'audit.
///
/// Le journal est en écriture seule : aucune entrée n'est modifiée ou
/// supprimée, une correction se traduit par une nouvelle entrée.
class AuditLog {
  const AuditLog({
    required this.id,
    required this.organizationId,
    required this.action,
    required this.description,
    required this.createdAt,
    this.actorMemberId,
    this.actorName = 'Système',
    this.targetType,
    this.targetId,
    this.tontineId,
    this.amount,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String organizationId;
  final AuditAction action;

  /// Phrase lisible : « YEO a enregistré une cotisation de 50 000 FCFA ».
  final String description;
  final String? actorMemberId;
  final String actorName;
  final String? targetType;
  final String? targetId;
  final String? tontineId;
  final double? amount;
  final Map<String, Object?> metadata;
  final DateTime createdAt;

  bool get isFinancial => action.isFinancial;
}
