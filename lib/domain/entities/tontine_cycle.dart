import 'package:kadjane/domain/enums/tontine_enums.dart';

/// Une période de cotisation d'une tontine (ex : « Août 2026 »).
class TontineCycle {
  const TontineCycle({
    required this.id,
    required this.tontineId,
    required this.index,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.expectedAmount,
    required this.status,
    this.beneficiaryParticipantId,
    this.beneficiaryId,
    this.drawSessionId,
    this.payoutId,
    this.drawScheduledAt,
  });

  final String id;
  final String tontineId;

  /// Numéro du cycle, à partir de 1.
  final int index;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Date limite de paiement des cotisations du cycle.
  final DateTime dueDate;

  /// Montant total attendu sur la période (cotisation x participants).
  final double expectedAmount;
  final CycleStatus status;
  final String? beneficiaryParticipantId;
  final String? beneficiaryId;
  final String? drawSessionId;
  final String? payoutId;
  final DateTime? drawScheduledAt;

  bool get isCurrent {
    final DateTime now = DateTime.now();
    return !now.isBefore(periodStart) && !now.isAfter(periodEnd);
  }

  bool get isPast => DateTime.now().isAfter(periodEnd);

  bool get hasBeneficiary => beneficiaryParticipantId != null;

  TontineCycle copyWith({
    double? expectedAmount,
    CycleStatus? status,
    String? beneficiaryParticipantId,
    String? beneficiaryId,
    String? drawSessionId,
    String? payoutId,
    DateTime? drawScheduledAt,
  }) => TontineCycle(
    id: id,
    tontineId: tontineId,
    index: index,
    periodStart: periodStart,
    periodEnd: periodEnd,
    dueDate: dueDate,
    expectedAmount: expectedAmount ?? this.expectedAmount,
    status: status ?? this.status,
    beneficiaryParticipantId:
        beneficiaryParticipantId ?? this.beneficiaryParticipantId,
    beneficiaryId: beneficiaryId ?? this.beneficiaryId,
    drawSessionId: drawSessionId ?? this.drawSessionId,
    payoutId: payoutId ?? this.payoutId,
    drawScheduledAt: drawScheduledAt ?? this.drawScheduledAt,
  );

  /// Retire la désignation du bénéficiaire (invalidation d'un tirage).
  ///
  /// Le cycle repart en collecte : le tirage invalidé reste, lui, conservé.
  TontineCycle clearBeneficiary() => TontineCycle(
    id: id,
    tontineId: tontineId,
    index: index,
    periodStart: periodStart,
    periodEnd: periodEnd,
    dueDate: dueDate,
    expectedAmount: expectedAmount,
    status: CycleStatus.collecting,
    drawScheduledAt: drawScheduledAt,
  );
}
