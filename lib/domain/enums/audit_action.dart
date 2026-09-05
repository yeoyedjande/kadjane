/// Actions tracées dans le journal d'audit.
///
/// Les événements financiers ne sont jamais supprimés : toute correction est
/// enregistrée comme une nouvelle entrée.
enum AuditAction {
  memberCreated('member.created'),
  memberUpdated('member.updated'),
  memberRoleChanged('member.role_changed'),
  tontineCreated('tontine.created'),
  tontineUpdated('tontine.updated'),
  tontineStatusChanged('tontine.status_changed'),
  contributionRecorded('contribution.recorded'),
  contributionConfirmed('contribution.confirmed'),
  contributionCancelled('contribution.cancelled'),
  drawScheduled('draw.scheduled'),
  drawCompleted('draw.completed'),
  drawOverridden('draw.overridden'),
  drawCancelled('draw.cancelled'),
  drawInvalidated('draw.invalidated'),
  orderGenerated('order.generated'),
  beneficiaryDesignated('beneficiary.designated'),
  payoutRecorded('payout.recorded'),
  payoutConfirmed('payout.confirmed'),
  transactionRecorded('transaction.recorded'),
  duesPlanCreated('dues.plan_created'),
  duesPlanUpdated('dues.plan_updated'),
  duesPaymentRecorded('dues.payment_recorded'),
  duesPaymentCancelled('dues.payment_cancelled'),
  organizationUpdated('organization.updated'),
  roleUpdated('role.updated'),
  roleReset('role.reset'),
  reminderSent('reminder.sent'),
  userLoggedIn('user.logged_in'),
  userLoggedOut('user.logged_out');

  const AuditAction(this.code);

  final String code;

  /// Une action financière ne peut jamais être effacée du journal.
  bool get isFinancial =>
      this == AuditAction.contributionRecorded ||
      this == AuditAction.contributionConfirmed ||
      this == AuditAction.contributionCancelled ||
      this == AuditAction.payoutRecorded ||
      this == AuditAction.payoutConfirmed ||
      this == AuditAction.transactionRecorded ||
      this == AuditAction.duesPaymentRecorded ||
      this == AuditAction.duesPaymentCancelled;

  static AuditAction fromCode(String value) => AuditAction.values.firstWhere(
    (AuditAction a) => a.code == value,
    orElse: () => AuditAction.organizationUpdated,
  );
}
