/// Canal d'envoi d'une relance.
///
/// `inApp` fonctionne sans intégration externe ; les autres canaux seront
/// branchés sur les passerelles correspondantes (SMS, WhatsApp Business,
/// e-mail transactionnel, Firebase Cloud Messaging).
enum ReminderChannel {
  inApp('in_app'),
  push('push'),
  sms('sms'),
  whatsapp('whatsapp'),
  email('email');

  const ReminderChannel(this.code);

  final String code;

  /// Canaux réellement opérationnels dans l'application aujourd'hui.
  bool get isDeliveredLocally => this == ReminderChannel.inApp;

  static ReminderChannel fromCode(String value) =>
      ReminderChannel.values.firstWhere(
        (ReminderChannel c) => c.code == value,
        orElse: () => ReminderChannel.inApp,
      );
}

/// Cycle de vie d'une relance.
enum ReminderStatus {
  queued('queued'),
  sent('sent'),
  read('read'),
  failed('failed');

  const ReminderStatus(this.code);

  final String code;

  static ReminderStatus fromCode(String value) =>
      ReminderStatus.values.firstWhere(
        (ReminderStatus s) => s.code == value,
        orElse: () => ReminderStatus.queued,
      );
}

/// Niveau d'escalade d'une relance, calculé à partir de l'échéance.
enum ReminderLevel {
  /// Avant l'échéance, dans la fenêtre de rappel de l'organisation.
  upcoming('upcoming'),

  /// Le jour de l'échéance.
  dueToday('due_today'),

  /// Après l'échéance, avant le seuil d'escalade.
  late_('late'),

  /// Retard prolongé : le bureau doit intervenir.
  escalated('escalated');

  const ReminderLevel(this.code);

  final String code;

  /// Ordre de gravité, utile pour trier une liste de relances.
  int get severity => ReminderLevel.values.indexOf(this);

  static ReminderLevel fromCode(String value) =>
      ReminderLevel.values.firstWhere(
        (ReminderLevel l) => l.code == value,
        orElse: () => ReminderLevel.upcoming,
      );
}
