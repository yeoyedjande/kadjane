import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';

/// Saisie d'un paiement par le trésorier.
class ContributionDraft {
  const ContributionDraft({
    required this.tontineId,
    required this.cycleId,
    required this.memberId,
    required this.amount,
    required this.method,
    this.paidAt,
    this.reference,
    this.comment,
    this.attachmentId,
    this.status = ContributionStatus.confirmed,
  });

  final String tontineId;
  final String cycleId;
  final String memberId;
  final double amount;
  final PaymentMethod method;
  final DateTime? paidAt;
  final String? reference;
  final String? comment;
  final String? attachmentId;
  final ContributionStatus status;
}

/// Cotisation attendue d'un participant pour un cycle, payée ou non.
///
/// Utilisée par la liste « Cotisations » : elle contient toujours une ligne par
/// participant, même sans paiement enregistré.
class ContributionSlot {
  const ContributionSlot({
    required this.memberId,
    required this.memberName,
    required this.expectedAmount,
    this.avatarUrl,
    this.contribution,
  });

  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final double expectedAmount;
  final Contribution? contribution;

  ContributionStatus? get status => contribution?.status;

  bool get isPaid => contribution?.countsAsCollected ?? false;

  double get paidAmount => isPaid ? contribution!.amount : 0;
}

abstract interface class ContributionRepository {
  /// Toutes les lignes attendues d'un cycle (payées ou non).
  Future<List<ContributionSlot>> slotsForCycle(String cycleId);

  Future<List<Contribution>> forCycle(String cycleId);

  Future<List<Contribution>> forTontine(String tontineId);

  /// Cotisations d'un membre dans toute l'organisation.
  Future<List<Contribution>> forMember({
    required String organizationId,
    required String memberId,
  });

  Future<Contribution> record({
    required ContributionDraft draft,
    required String actorMemberId,
  });

  Future<Contribution> confirm({
    required String contributionId,
    required String actorMemberId,
  });

  /// Annulation : la cotisation reste dans l'historique mais ne compte plus
  /// dans le montant collecté.
  Future<Contribution> cancel({
    required String contributionId,
    required String reason,
    required String actorMemberId,
  });
}
