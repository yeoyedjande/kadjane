/// Types de notifications envoyées aux membres.
///
/// L'architecture est prête pour Firebase Cloud Messaging : le `code` sert de
/// clé dans le payload `data` du push.
enum NotificationType {
  contributionDue('contribution_due'),
  contributionLate('contribution_late'),
  paymentConfirmed('payment_confirmed'),
  drawScheduled('draw_scheduled'),
  drawResult('draw_result'),
  potComplete('pot_complete'),
  payoutDone('payout_done'),
  newMember('new_member'),
  announcement('announcement');

  const NotificationType(this.code);

  final String code;

  static NotificationType fromCode(String value) =>
      NotificationType.values.firstWhere(
        (NotificationType t) => t.code == value,
        orElse: () => NotificationType.announcement,
      );
}
