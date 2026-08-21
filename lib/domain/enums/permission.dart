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
  memberInvite('member.invite'),

  // Tontines
  tontineView('tontine.view'),
  tontineCreate('tontine.create'),
  tontineEdit('tontine.edit'),
  tontineValidate('tontine.validate'),

  // Cotisations
  contributionView('contribution.view'),
  contributionRecord('contribution.record'),
  contributionConfirm('contribution.confirm'),
  contributionCancel('contribution.cancel'),

  // Tirage
  drawView('draw.view'),
  drawRun('draw.run'),
  drawOverride('draw.override'),
  drawInvalidate('draw.invalidate'),

  // Versements
  payoutView('payout.view'),
  payoutRecord('payout.record'),

  // Caisse
  treasuryView('treasury.view'),
  treasuryManage('treasury.manage'),

  // Relances
  reminderView('reminder.view'),
  reminderSend('reminder.send'),

  // Rapports & audit
  reportView('report.view'),
  auditView('audit.view');

  const Permission(this.code);

  final String code;

  static Permission fromCode(String value) => Permission.values.firstWhere(
    (Permission p) => p.code == value,
    orElse: () => Permission.organizationView,
  );
}
