/// Participation d'un membre à une tontine.
///
/// RÈGLE MÉTIER FONDAMENTALE : recevoir la cagnotte retire le participant des
/// **prochains tirages** ([isEligibleForDraw] = false) mais **pas** de la
/// tontine. Il continue de cotiser et reste visible dans tous les rapports.
class TontineParticipant {
  const TontineParticipant({
    required this.id,
    required this.tontineId,
    required this.memberId,
    required this.displayName,
    required this.joinedAt,
    this.avatarUrl,
    this.isEligibleForDraw = true,
    this.hasReceivedPot = false,
    this.receivedCycleId,
    this.receivedPeriodStart,
    this.orderPosition,
    this.isActive = true,
  });

  final String id;
  final String tontineId;
  final String memberId;

  /// Nom conservé au moment du tirage (preuve lisible même si le membre change).
  final String displayName;
  final String? avatarUrl;
  final DateTime joinedAt;

  /// Éligibilité aux prochains tirages uniquement.
  final bool isEligibleForDraw;

  /// A déjà reçu la cagnotte au moins une fois.
  final bool hasReceivedPot;
  final String? receivedCycleId;
  final DateTime? receivedPeriodStart;

  /// Position de passage (modes ordre complet / ordre manuel).
  final int? orderPosition;

  /// Participation toujours en cours (le membre cotise).
  final bool isActive;

  /// Doit-il encore cotiser ? Oui, même après avoir reçu la cagnotte.
  bool get mustKeepContributing => isActive;

  TontineParticipant copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isEligibleForDraw,
    bool? hasReceivedPot,
    String? receivedCycleId,
    DateTime? receivedPeriodStart,
    int? orderPosition,
    bool? isActive,
  }) => TontineParticipant(
    id: id,
    tontineId: tontineId,
    memberId: memberId,
    displayName: displayName ?? this.displayName,
    joinedAt: joinedAt,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isEligibleForDraw: isEligibleForDraw ?? this.isEligibleForDraw,
    hasReceivedPot: hasReceivedPot ?? this.hasReceivedPot,
    receivedCycleId: receivedCycleId ?? this.receivedCycleId,
    receivedPeriodStart: receivedPeriodStart ?? this.receivedPeriodStart,
    orderPosition: orderPosition ?? this.orderPosition,
    isActive: isActive ?? this.isActive,
  );

  /// Marque le participant comme bénéficiaire d'un cycle.
  ///
  /// Il reste membre actif de la tontine et continue de cotiser.
  TontineParticipant markAsBeneficiary({
    required String cycleId,
    required DateTime periodStart,
  }) => copyWith(
    hasReceivedPot: true,
    isEligibleForDraw: false,
    receivedCycleId: cycleId,
    receivedPeriodStart: periodStart,
  );

  /// Rend le participant de nouveau éligible (invalidation d'un tirage).
  TontineParticipant resetBeneficiaryStatus() => TontineParticipant(
    id: id,
    tontineId: tontineId,
    memberId: memberId,
    displayName: displayName,
    joinedAt: joinedAt,
    avatarUrl: avatarUrl,
    orderPosition: orderPosition,
    isActive: isActive,
  );
}
