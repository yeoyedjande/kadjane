import 'package:kadjane/domain/enums/payment_enums.dart';

/// Cotisation d'un membre pour un cycle donné.
class Contribution {
  const Contribution({
    required this.id,
    required this.organizationId,
    required this.tontineId,
    required this.cycleId,
    required this.memberId,
    required this.amount,
    required this.status,
    required this.recordedAt,
    this.memberName = '',
    this.method,
    this.reference,
    this.comment,
    this.attachmentId,
    this.paidAt,
    this.recordedBy,
    this.cancelledAt,
    this.cancelReason,
  });

  final String id;
  final String organizationId;
  final String tontineId;
  final String cycleId;
  final String memberId;

  /// Nom du membre au moment de l'enregistrement (affichage des listes).
  final String memberName;
  final double amount;
  final ContributionStatus status;
  final PaymentMethod? method;
  final String? reference;
  final String? comment;
  final String? attachmentId;
  final DateTime? paidAt;

  /// Membre (trésorier) ayant enregistré l'opération.
  final String? recordedBy;
  final DateTime recordedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  /// Seules les cotisations confirmées comptent dans le montant collecté.
  bool get countsAsCollected => status.countsAsCollected;

  bool get isSettled =>
      status == ContributionStatus.confirmed ||
      status == ContributionStatus.pending;

  Contribution copyWith({
    double? amount,
    ContributionStatus? status,
    PaymentMethod? method,
    String? reference,
    String? comment,
    String? attachmentId,
    DateTime? paidAt,
    String? recordedBy,
    DateTime? cancelledAt,
    String? cancelReason,
  }) => Contribution(
    id: id,
    organizationId: organizationId,
    tontineId: tontineId,
    cycleId: cycleId,
    memberId: memberId,
    amount: amount ?? this.amount,
    status: status ?? this.status,
    recordedAt: recordedAt,
    memberName: memberName,
    method: method ?? this.method,
    reference: reference ?? this.reference,
    comment: comment ?? this.comment,
    attachmentId: attachmentId ?? this.attachmentId,
    paidAt: paidAt ?? this.paidAt,
    recordedBy: recordedBy ?? this.recordedBy,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancelReason: cancelReason ?? this.cancelReason,
  );
}
