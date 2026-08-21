import 'package:kadjane/domain/enums/draw_enums.dart';

/// Bénéficiaire désigné pour un cycle de tontine.
class Beneficiary {
  const Beneficiary({
    required this.id,
    required this.organizationId,
    required this.tontineId,
    required this.cycleId,
    required this.participantId,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.designatedAt,
    required this.source,
    this.avatarUrl,
    this.drawSessionId,
    this.payoutId,
  });

  final String id;
  final String organizationId;
  final String tontineId;

  /// Un seul bénéficiaire par cycle : cette contrainte est vérifiée par le
  /// repository et couverte par les tests.
  final String cycleId;
  final String participantId;
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final double amount;
  final DateTime designatedAt;
  final BeneficiarySource source;
  final String? drawSessionId;
  final String? payoutId;

  Beneficiary copyWith({String? payoutId}) => Beneficiary(
    id: id,
    organizationId: organizationId,
    tontineId: tontineId,
    cycleId: cycleId,
    participantId: participantId,
    memberId: memberId,
    memberName: memberName,
    amount: amount,
    designatedAt: designatedAt,
    source: source,
    avatarUrl: avatarUrl,
    drawSessionId: drawSessionId,
    payoutId: payoutId ?? this.payoutId,
  );
}
