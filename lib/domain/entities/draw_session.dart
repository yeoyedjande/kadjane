import 'package:kadjane/domain/enums/draw_enums.dart';

/// Participant figé dans la preuve d'un tirage.
class DrawParticipant {
  const DrawParticipant({
    required this.participantId,
    required this.memberId,
    required this.displayName,
    this.weight = 1,
  });

  final String participantId;
  final String memberId;
  final String displayName;

  /// Réservé à une pondération future (ex : parts multiples).
  final int weight;
}

/// Session de tirage au sort : la trace inaltérable d'une désignation.
///
/// Un tirage validé n'est jamais modifié silencieusement ni supprimé : on
/// l'annule ou on l'invalide, et chaque opération alimente le journal d'audit.
class DrawSession {
  const DrawSession({
    required this.id,
    required this.organizationId,
    required this.tontineId,
    required this.cycleId,
    required this.periodLabel,
    required this.participants,
    required this.status,
    required this.createdAt,
    required this.proofReference,
    required this.randomSourceLabel,
    this.scheduledAt,
    this.executedAt,
    this.winnerParticipantId,
    this.winnerMemberId,
    this.winnerName,
    this.launchedByMemberId,
    this.launchedByName,
    this.seed,
    this.overrideUsed = false,
    this.overrideReason,
    this.closedAt,
    this.closeReason,
  });

  final String id;
  final String organizationId;
  final String tontineId;
  final String cycleId;

  /// Période concernée, figée à la création (ex : « Août 2026 »).
  final String periodLabel;

  /// Participants éligibles au moment du tirage.
  final List<DrawParticipant> participants;
  final DrawStatus status;
  final DateTime? scheduledAt;
  final DateTime? executedAt;
  final String? winnerParticipantId;
  final String? winnerMemberId;
  final String? winnerName;
  final String? launchedByMemberId;
  final String? launchedByName;

  /// Référence de preuve affichée à l'utilisateur et conservée en audit.
  final String proofReference;

  /// Source d'aléa utilisée (client sécurisé, graine, serveur...).
  final String randomSourceLabel;
  final int? seed;

  /// Le tirage a-t-il été forcé malgré des cotisations manquantes ?
  final bool overrideUsed;
  final String? overrideReason;
  final DateTime? closedAt;
  final String? closeReason;
  final DateTime createdAt;

  bool get isCompleted => status == DrawStatus.completed;

  bool get isEditable => status == DrawStatus.scheduled;

  int get eligibleCount => participants.length;

  DrawSession copyWith({
    List<DrawParticipant>? participants,
    DrawStatus? status,
    DateTime? scheduledAt,
    DateTime? executedAt,
    String? winnerParticipantId,
    String? winnerMemberId,
    String? winnerName,
    String? launchedByMemberId,
    String? launchedByName,
    String? randomSourceLabel,
    int? seed,
    bool? overrideUsed,
    String? overrideReason,
    DateTime? closedAt,
    String? closeReason,
  }) => DrawSession(
    id: id,
    organizationId: organizationId,
    tontineId: tontineId,
    cycleId: cycleId,
    periodLabel: periodLabel,
    participants: participants ?? this.participants,
    status: status ?? this.status,
    createdAt: createdAt,
    proofReference: proofReference,
    randomSourceLabel: randomSourceLabel ?? this.randomSourceLabel,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    executedAt: executedAt ?? this.executedAt,
    winnerParticipantId: winnerParticipantId ?? this.winnerParticipantId,
    winnerMemberId: winnerMemberId ?? this.winnerMemberId,
    winnerName: winnerName ?? this.winnerName,
    launchedByMemberId: launchedByMemberId ?? this.launchedByMemberId,
    launchedByName: launchedByName ?? this.launchedByName,
    seed: seed ?? this.seed,
    overrideUsed: overrideUsed ?? this.overrideUsed,
    overrideReason: overrideReason ?? this.overrideReason,
    closedAt: closedAt ?? this.closedAt,
    closeReason: closeReason ?? this.closeReason,
  );
}
