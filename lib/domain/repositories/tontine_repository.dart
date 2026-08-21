import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';

/// Données saisies dans le wizard de création d'une tontine.
class TontineDraft {
  const TontineDraft({
    required this.name,
    required this.contributionAmount,
    required this.currency,
    required this.frequency,
    required this.allocationMode,
    required this.startDate,
    required this.memberIds,
    this.description,
    this.dueDayOfPeriod = 5,
    this.customPeriodDays,

    /// Ordre manuel : identifiants de membres dans l'ordre de passage.
    this.manualOrder = const <String>[],
  });

  final String name;
  final String? description;
  final double contributionAmount;
  final Currency currency;
  final TontineFrequency frequency;
  final AllocationMode allocationMode;
  final DateTime startDate;
  final int dueDayOfPeriod;
  final int? customPeriodDays;
  final List<String> memberIds;
  final List<String> manualOrder;

  double get estimatedPot => contributionAmount * memberIds.length;
}

/// Vue agrégée d'une tontine pour les listes et le dashboard.
class TontineSummary {
  const TontineSummary({
    required this.tontine,
    required this.participantCount,
    required this.completedCycles,
    required this.totalCycles,
    required this.collectedCurrentCycle,
    required this.expectedCurrentCycle,
    this.currentCycle,
    this.currentBeneficiaryName,
    this.previousBeneficiaryName,
  });

  final Tontine tontine;
  final int participantCount;
  final int completedCycles;
  final int totalCycles;
  final double collectedCurrentCycle;
  final double expectedCurrentCycle;
  final TontineCycle? currentCycle;
  final String? currentBeneficiaryName;
  final String? previousBeneficiaryName;

  double get pot => tontine.potFor(participantCount);

  double get progress =>
      totalCycles == 0 ? 0 : (completedCycles / totalCycles).clamp(0, 1);

  double get collectionProgress => expectedCurrentCycle <= 0
      ? 0
      : (collectedCurrentCycle / expectedCurrentCycle).clamp(0, 1);
}

abstract interface class TontineRepository {
  Future<List<TontineSummary>> list({
    required String organizationId,
    TontineStatus? status,
    String? memberId,
  });

  Future<TontineSummary> summaryOf(String tontineId);

  Future<Tontine> byId(String tontineId);

  Future<Tontine> create({
    required String organizationId,
    required TontineDraft draft,
    required String actorMemberId,
  });

  Future<Tontine> update({
    required Tontine tontine,
    required String actorMemberId,
  });

  Future<Tontine> changeStatus({
    required String tontineId,
    required TontineStatus status,
    required String actorMemberId,
  });

  Future<List<TontineParticipant>> participants(String tontineId);

  Future<List<TontineCycle>> cycles(String tontineId);

  Future<TontineCycle> cycleById(String cycleId);

  /// Cycle en cours (ou prochain cycle ouvert).
  Future<TontineCycle?> currentCycle(String tontineId);

  /// Mode C : définition manuelle de l'ordre de passage.
  Future<void> setManualOrder({
    required String tontineId,
    required List<String> participantIdsInOrder,
    required String actorMemberId,
  });
}
