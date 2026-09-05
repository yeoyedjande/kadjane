import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/services/period_calculator.dart';

/// Raison pour laquelle un tirage est bloqué.
enum DrawBlockReason {
  none,
  tontineNotActive,
  alreadyDrawn,
  missingContributions,
  noEligibleParticipant,
  orderAlreadyDefined,

  /// Le jour de tirage convenu n'est pas encore arrivé.
  drawNotOpenYet,
}

/// Résultat de l'évaluation des conditions d'un tirage.
class DrawEligibility {
  const DrawEligibility({
    required this.allowed,
    required this.reason,
    required this.missingContributions,
    required this.canOverride,
    this.drawOpensAt,
  });

  const DrawEligibility.allowed({this.drawOpensAt})
    : allowed = true,
      reason = DrawBlockReason.none,
      missingContributions = 0,
      canOverride = false;

  final bool allowed;
  final DrawBlockReason reason;
  final int missingContributions;

  /// Vrai si un administrateur peut forcer le tirage (avec audit).
  final bool canOverride;

  /// Date d'ouverture du tirage pour la période en cours.
  final DateTime? drawOpensAt;
}

/// Situation financière d'un cycle.
class CycleFinancials {
  const CycleFinancials({
    required this.expected,
    required this.collected,
    required this.paidMembers,
    required this.totalMembers,
  });

  final double expected;
  final double collected;
  final int paidMembers;
  final int totalMembers;

  double get remaining => (expected - collected).clamp(0, double.infinity);

  int get unpaidMembers => (totalMembers - paidMembers).clamp(0, totalMembers);

  double get progress => expected <= 0 ? 0 : (collected / expected).clamp(0, 1);

  bool get isComplete => collected >= expected && expected > 0;
}

/// Règles métier de la tontine, indépendantes de toute source de données.
class TontineRulesService {
  const TontineRulesService();

  /// Participants pouvant encore être tirés au sort.
  ///
  /// Un ancien bénéficiaire reste participant actif mais n'est plus éligible.
  List<TontineParticipant> eligibleForDraw(
    List<TontineParticipant> participants,
  ) => participants
      .where(
        (TontineParticipant p) =>
            p.isActive && p.isEligibleForDraw && !p.hasReceivedPot,
      )
      .toList(growable: false);

  /// Participants devant cotiser sur la période (y compris les bénéficiaires).
  List<TontineParticipant> contributors(
    List<TontineParticipant> participants,
  ) => participants
      .where((TontineParticipant p) => p.mustKeepContributing)
      .toList(growable: false);

  /// Montant réellement collecté : seules les cotisations confirmées comptent.
  double collectedAmount(List<Contribution> contributions) => contributions
      .where((Contribution c) => c.countsAsCollected)
      .fold<double>(0, (double sum, Contribution c) => sum + c.amount);

  /// Membres ayant une cotisation confirmée sur le cycle.
  Set<String> paidMemberIds(List<Contribution> contributions) => contributions
      .where((Contribution c) => c.countsAsCollected)
      .map((Contribution c) => c.memberId)
      .toSet();

  CycleFinancials financialsFor({
    required Tontine tontine,
    required TontineCycle cycle,
    required List<TontineParticipant> participants,
    required List<Contribution> contributions,
  }) {
    final List<TontineParticipant> due = contributors(participants);
    final Set<String> paid = paidMemberIds(contributions);
    return CycleFinancials(
      expected: tontine.contributionAmount * due.length,
      collected: collectedAmount(contributions),
      paidMembers: due
          .where((TontineParticipant p) => paid.contains(p.memberId))
          .length,
      totalMembers: due.length,
    );
  }

  /// Membres en retard : pas de cotisation confirmée après la date limite.
  List<TontineParticipant> lateParticipants({
    required TontineCycle cycle,
    required List<TontineParticipant> participants,
    required List<Contribution> contributions,
    required OrganizationSettings settings,
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime limit = cycle.dueDate.add(
      Duration(days: settings.latePaymentGraceDays),
    );
    if (reference.isBefore(limit)) {
      return const <TontineParticipant>[];
    }
    final Set<String> paid = paidMemberIds(contributions);
    return contributors(participants)
        .where((TontineParticipant p) => !paid.contains(p.memberId))
        .toList(growable: false);
  }

  /// Vérifie toutes les conditions d'un tirage périodique (mode A).
  DrawEligibility evaluateDraw({
    required Tontine tontine,
    required TontineCycle cycle,
    required OrganizationSettings settings,
    required List<TontineParticipant> participants,
    required List<Contribution> contributions,
  }) {
    if (tontine.status != TontineStatus.active) {
      return const DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.tontineNotActive,
        missingContributions: 0,
        canOverride: false,
      );
    }
    if (cycle.hasBeneficiary) {
      return const DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.alreadyDrawn,
        missingContributions: 0,
        canOverride: false,
      );
    }
    final List<TontineParticipant> eligible = eligibleForDraw(participants);
    if (eligible.isEmpty) {
      return const DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.noEligibleParticipant,
        missingContributions: 0,
        canOverride: false,
      );
    }
    // Le tirage s'ouvre à une date convenue : c'est le rythme d'une tontine,
    // un bénéficiaire par période. Réclamer les cotisations avant ce jour
    // n'apprendrait rien — elles ne sont pas encore en retard.
    final DateTime opensAt =
        cycle.drawScheduledAt ??
        const PeriodCalculator().drawOpeningFor(
          periodStart: cycle.periodStart,
          periodEnd: cycle.periodEnd,
          drawDay: tontine.drawDayOfPeriod,
        );
    if (DateTime.now().isBefore(opensAt)) {
      return DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.drawNotOpenYet,
        missingContributions: 0,
        canOverride: tontine.allowDrawOverride && settings.allowDrawOverride,
        drawOpensAt: opensAt,
      );
    }

    final CycleFinancials financials = financialsFor(
      tontine: tontine,
      cycle: cycle,
      participants: participants,
      contributions: contributions,
    );
    // La règle de la tontine prime : elle est initialisée depuis les réglages
    // de l'organisation à la création, puis se règle tontine par tontine.
    // [settings] ne fait plus que borner ce que l'organisation autorise.
    if (tontine.requireAllContributionsBeforeDraw &&
        financials.unpaidMembers > 0) {
      return DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.missingContributions,
        missingContributions: financials.unpaidMembers,
        canOverride: tontine.allowDrawOverride && settings.allowDrawOverride,
        drawOpensAt: opensAt,
      );
    }
    return DrawEligibility.allowed(drawOpensAt: opensAt);
  }

  /// Position d'un membre dans une tontine à ordre prédéfini (modes B et C).
  TontineParticipant? participantOf(
    List<TontineParticipant> participants,
    String memberId,
  ) {
    for (final TontineParticipant p in participants) {
      if (p.memberId == memberId) {
        return p;
      }
    }
    return null;
  }
}
