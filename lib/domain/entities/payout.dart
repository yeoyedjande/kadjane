import 'package:kadjane/domain/enums/payment_enums.dart';

/// Versement de la cagnotte au bénéficiaire d'un cycle.
class Payout {
  const Payout({
    required this.id,
    required this.organizationId,
    required this.tontineId,
    required this.cycleId,
    required this.beneficiaryId,
    required this.memberId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.memberName = '',
    this.method,
    this.reference,
    this.comment,
    this.attachmentId,
    this.sentAt,
    this.recordedBy,
  });

  final String id;
  final String organizationId;
  final String tontineId;
  final String cycleId;
  final String beneficiaryId;
  final String memberId;
  final String memberName;
  final double amount;
  final PayoutStatus status;
  final PaymentMethod? method;
  final String? reference;
  final String? comment;
  final String? attachmentId;
  final DateTime? sentAt;
  final String? recordedBy;
  final DateTime createdAt;

  bool get isPaid => status == PayoutStatus.paid;

  Payout copyWith({
    double? amount,
    PayoutStatus? status,
    PaymentMethod? method,
    String? reference,
    String? comment,
    String? attachmentId,
    DateTime? sentAt,
    String? recordedBy,
  }) => Payout(
    id: id,
    organizationId: organizationId,
    tontineId: tontineId,
    cycleId: cycleId,
    beneficiaryId: beneficiaryId,
    memberId: memberId,
    amount: amount ?? this.amount,
    status: status ?? this.status,
    createdAt: createdAt,
    memberName: memberName,
    method: method ?? this.method,
    reference: reference ?? this.reference,
    comment: comment ?? this.comment,
    attachmentId: attachmentId ?? this.attachmentId,
    sentAt: sentAt ?? this.sentAt,
    recordedBy: recordedBy ?? this.recordedBy,
  );
}
