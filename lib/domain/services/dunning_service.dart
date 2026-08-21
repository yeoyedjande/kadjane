import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Membre à relancer pour une période donnée.
class DunningTarget {
  const DunningTarget({
    required this.memberId,
    required this.memberName,
    required this.tontineId,
    required this.tontineName,
    required this.cycleId,
    required this.periodStart,
    required this.dueDate,
    required this.amountDue,
    required this.level,
    required this.daysLate,
    required this.reminderCount,
    this.lastReminderAt,
  });

  final String memberId;
  final String memberName;
  final String tontineId;
  final String tontineName;
  final String cycleId;
  final DateTime periodStart;
  final DateTime dueDate;
  final double amountDue;
  final ReminderLevel level;

  /// Négatif avant l'échéance, positif après.
  final int daysLate;

  /// Nombre de relances déjà envoyées pour cette cotisation.
  final int reminderCount;
  final DateTime? lastReminderAt;

  bool get isOverdue => daysLate > 0;

  /// Une relance déjà envoyée aujourd'hui évite le harcèlement.
  bool remindedSince(DateTime reference) =>
      lastReminderAt != null && lastReminderAt!.isAfter(reference);
}

/// Calcule qui relancer, à quel niveau d'escalade, et compose le message.
///
/// Le service est purement métier : il ne connaît ni le réseau, ni l'interface,
/// ce qui permet de l'utiliser aussi bien depuis la console d'administration
/// que depuis l'application mobile, et de le tester directement.
class DunningService {
  const DunningService({
    this.escalationAfterDays = 7,
    this.rules = const TontineRulesService(),
  });

  /// Au-delà de ce retard, la relance passe en niveau critique.
  final int escalationAfterDays;
  final TontineRulesService rules;

  /// Membres à relancer pour un cycle.
  ///
  /// Un membre est ciblé s'il n'a pas de cotisation confirmée et que l'échéance
  /// approche (fenêtre de rappel de l'organisation) ou est dépassée. Les
  /// anciens bénéficiaires sont inclus : ils continuent de cotiser.
  List<DunningTarget> targetsForCycle({
    required Tontine tontine,
    required TontineCycle cycle,
    required OrganizationSettings settings,
    required List<TontineParticipant> participants,
    required List<Contribution> contributions,
    List<Reminder> reminders = const <Reminder>[],
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final Set<String> paid = rules.paidMemberIds(contributions);
    final List<DunningTarget> targets = <DunningTarget>[];

    for (final TontineParticipant participant in rules.contributors(
      participants,
    )) {
      if (paid.contains(participant.memberId)) {
        continue;
      }
      final int daysLate = _daysBetween(cycle.dueDate, reference);
      // Trop tôt : on ne sollicite pas avant la fenêtre de rappel.
      if (daysLate < -settings.notifyBeforeDueDays) {
        continue;
      }
      final List<Reminder> history =
          reminders
              .where(
                (Reminder r) =>
                    r.cycleId == cycle.id && r.memberId == participant.memberId,
              )
              .toList()
            ..sort(
              (Reminder a, Reminder b) => b.createdAt.compareTo(a.createdAt),
            );

      targets.add(
        DunningTarget(
          memberId: participant.memberId,
          memberName: participant.displayName,
          tontineId: tontine.id,
          tontineName: tontine.name,
          cycleId: cycle.id,
          periodStart: cycle.periodStart,
          dueDate: cycle.dueDate,
          amountDue: tontine.contributionAmount,
          level: levelFor(daysLate),
          daysLate: daysLate,
          reminderCount: history.length,
          lastReminderAt: history.isEmpty ? null : history.first.createdAt,
        ),
      );
    }

    targets.sort((DunningTarget a, DunningTarget b) {
      final int bySeverity = b.level.severity.compareTo(a.level.severity);
      return bySeverity != 0
          ? bySeverity
          : a.memberName.compareTo(b.memberName);
    });
    return List<DunningTarget>.unmodifiable(targets);
  }

  /// Niveau d'escalade correspondant à un retard exprimé en jours.
  ReminderLevel levelFor(int daysLate) {
    if (daysLate < 0) {
      return ReminderLevel.upcoming;
    }
    if (daysLate == 0) {
      return ReminderLevel.dueToday;
    }
    return daysLate > escalationAfterDays
        ? ReminderLevel.escalated
        : ReminderLevel.late_;
  }

  /// Remplace les variables d'un modèle de message.
  ///
  /// Variables disponibles : `{membre}`, `{montant}`, `{tontine}`,
  /// `{periode}`, `{echeance}`, `{organisation}`, `{retard}`.
  static String render(
    String template, {
    required String memberName,
    required String amount,
    required String tontineName,
    required String periodLabel,
    required String dueDate,
    required String organizationName,
    required int daysLate,
  }) {
    return template
        .replaceAll('{membre}', memberName)
        .replaceAll('{montant}', amount)
        .replaceAll('{tontine}', tontineName)
        .replaceAll('{periode}', periodLabel)
        .replaceAll('{echeance}', dueDate)
        .replaceAll('{organisation}', organizationName)
        .replaceAll('{retard}', '${daysLate.abs()}');
  }

  /// Modèle proposé par défaut selon le niveau d'escalade.
  static String defaultTemplate(ReminderLevel level) {
    switch (level) {
      case ReminderLevel.upcoming:
        return 'Bonjour {membre}, votre cotisation de {montant} pour '
            '{tontine} ({periode}) est attendue le {echeance}. Merci !';
      case ReminderLevel.dueToday:
        return 'Bonjour {membre}, votre cotisation de {montant} pour '
            '{tontine} ({periode}) est due aujourd\'hui. Merci de régulariser.';
      case ReminderLevel.late_:
        return 'Bonjour {membre}, votre cotisation de {montant} pour '
            '{tontine} ({periode}) est en retard de {retard} jour(s). '
            'Le tirage ne peut pas être lancé tant qu\'elle n\'est pas réglée.';
      case ReminderLevel.escalated:
        return 'Bonjour {membre}, votre cotisation de {montant} pour '
            '{tontine} ({periode}) accuse {retard} jours de retard. '
            'Merci de contacter le bureau de {organisation} rapidement.';
    }
  }

  static int _daysBetween(DateTime dueDate, DateTime reference) {
    final DateTime due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final DateTime now = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    return now.difference(due).inDays;
  }
}
