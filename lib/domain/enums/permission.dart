/// Permissions atomiques de la plateforme.
///
/// Les écrans testent une permission (`PermissionService.can(...)`) et jamais
/// un rôle : ajouter un rôle ne demande donc aucune modification d'UI.
enum Permission {
  // Organisation
  organizationView('organization.view'),
  organizationEdit('organization.edit'),
  organizationManageOfficers('organization.manage_officers'),

  // Membres
  memberView('member.view'),
  memberCreate('member.create'),
  memberEdit('member.edit'),
  memberDelete('member.delete'),
  memberDisable('member.disable'),
  memberInvite('member.invite'),

  // Caisse de l'association (cotisations hors tontine)
  duesView('dues.view'),
  duesRecord('dues.record'),
  duesManage('dues.manage'),

  // Tontines
  tontineView('tontine.view'),
  tontineCreate('tontine.create'),
  tontineEdit('tontine.edit'),
  tontineValidate('tontine.validate'),
  tontineSuspend('tontine.suspend'),

  // Cotisations
  contributionView('contribution.view'),
  contributionCreate('contribution.create'),
  contributionUpdate('contribution.update'),
  contributionRecord('contribution.record'),
  contributionMarkPaid('contribution.mark_paid'),
  contributionMarkLate('contribution.mark_late'),
  contributionExempt('contribution.exempt'),
  contributionConfirm('contribution.confirm'),
  contributionCancel('contribution.cancel'),

  // Paiements
  paymentView('payment.view'),
  paymentCreate('payment.create'),
  paymentConfirm('payment.confirm'),
  paymentReject('payment.reject'),
  paymentCancel('payment.cancel'),

  // Tirage
  drawView('draw.view'),
  drawRun('draw.run'),
  drawOverride('draw.override'),
  drawInvalidate('draw.invalidate'),

  // Versements
  payoutView('payout.view'),
  payoutRecord('payout.record'),
  payoutConfirm('payout.confirm'),
  payoutCancel('payout.cancel'),

  // Caisse
  cashboxView('cashbox.view'),
  cashboxCreate('cashbox.create'),
  cashboxUpdate('cashbox.update'),
  cashboxClose('cashbox.close'),
  cashTransactionCreate('cash_transaction.create'),
  cashTransactionUpdate('cash_transaction.update'),
  cashTransactionCancel('cash_transaction.cancel'),
  treasuryView('treasury.view'),
  treasuryManage('treasury.manage'),

  // Relances
  reminderView('reminder.view'),
  reminderSend('reminder.send'),

  // Rapports & audit
  reportView('report.view'),
  auditView('audit.view'),

  // Administration
  userView('user.view'),
  userCreate('user.create'),
  userUpdate('user.update'),
  roleView('role.view'),
  roleCreate('role.create'),
  roleUpdate('role.update'),
  roleAssign('role.assign'),
  permissionView('permission.view'),
  permissionAssign('permission.assign');

  const Permission(this.code);

  final String code;

  static final Map<String, Permission> _byCode = <String, Permission>{
    for (final Permission permission in Permission.values)
      permission.code: permission,
  };

  /// `null` pour un code inconnu de cette version du client.
  ///
  /// Le serveur peut en servir un que l'application ne connaît pas encore :
  /// l'ignorer vaut mieux que de le confondre avec un autre droit — ce que
  /// faisait l'ancien repli sur `organizationView`.
  static Permission? tryFromCode(String value) => _byCode[value];

  static Permission fromCode(String value) =>
      _byCode[value] ?? Permission.organizationView;
}
