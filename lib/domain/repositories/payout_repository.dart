import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';

class PayoutDraft {
  const PayoutDraft({
    required this.beneficiaryId,
    required this.amount,
    required this.method,
    required this.sentAt,
    this.reference,
    this.comment,
    this.attachmentId,
    this.status = PayoutStatus.paid,
  });

  final String beneficiaryId;
  final double amount;
  final PaymentMethod method;
  final DateTime sentAt;
  final String? reference;
  final String? comment;
  final String? attachmentId;
  final PayoutStatus status;
}

/// Bénéficiaires et versements de cagnotte.
abstract interface class PayoutRepository {
  Future<List<Beneficiary>> beneficiariesOf(String tontineId);

  Future<Beneficiary?> beneficiaryOfCycle(String cycleId);

  Future<Beneficiary> beneficiaryById(String beneficiaryId);

  /// Mode C / correction : désignation manuelle par un administrateur.
  Future<Beneficiary> designateManually({
    required String cycleId,
    required String participantId,
    required String actorMemberId,
  });

  Future<Payout?> payoutOfCycle(String cycleId);

  Future<List<Payout>> payoutsOf(String tontineId);

  Future<Payout> record({
    required PayoutDraft draft,
    required String actorMemberId,
  });

  /// Sommes déjà reçues par un membre (toutes tontines de l'organisation).
  Future<double> totalReceivedBy({
    required String organizationId,
    required String memberId,
  });
}
