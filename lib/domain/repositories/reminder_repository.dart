import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/services/dunning_service.dart';

/// Demande d'envoi groupé de relances.
class ReminderCampaignDraft {
  const ReminderCampaignDraft({
    required this.tontineId,
    required this.cycleId,
    required this.channels,
    required this.messages,
  });

  final String tontineId;
  final String cycleId;
  final List<ReminderChannel> channels;

  /// Message définitif par membre (déjà personnalisé).
  final Map<String, String> messages;

  List<String> get memberIds => messages.keys.toList(growable: false);
}

/// Résultat d'une campagne de relance.
class ReminderCampaignResult {
  const ReminderCampaignResult({
    required this.campaign,
    required this.reminders,
  });

  final ReminderCampaign campaign;
  final List<Reminder> reminders;

  int get sent => reminders.where((Reminder r) => r.isDelivered).length;
}

/// Relances et campagnes.
///
/// TODO(api): brancher les passerelles SMS / WhatsApp / e-mail côté backend ;
/// l'application se contente de déclencher la campagne et d'en suivre l'état.
abstract interface class ReminderRepository {
  /// Membres à relancer pour un cycle, avec leur niveau d'escalade.
  Future<List<DunningTarget>> targetsForCycle({
    required String tontineId,
    required String cycleId,
  });

  /// Ensemble des membres à relancer dans l'organisation (tous cycles ouverts).
  Future<List<DunningTarget>> targetsForOrganization(String organizationId);

  Future<ReminderCampaignResult> sendCampaign({
    required ReminderCampaignDraft draft,
    required String actorMemberId,
  });

  Future<List<ReminderCampaign>> campaignsOf(String organizationId);

  /// Relances reçues par un membre (son espace personnel).
  Future<List<Reminder>> forMember({
    required String organizationId,
    required String memberId,
  });

  Future<List<Reminder>> forCycle(String cycleId);

  Future<void> markAsRead(String reminderId);
}
