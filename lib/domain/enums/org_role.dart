/// Rôles disponibles dans une organisation.
///
/// Les droits associés ne sont jamais codés dans les écrans : voir
/// `PermissionService` et `Permission`.
enum OrgRole {
  superAdmin('super_admin', 100),
  admin('admin', 80),
  president('president', 70),
  treasurer('treasurer', 60),
  auditor('auditor', 40),
  member('member', 10);

  const OrgRole(this.code, this.level);

  final String code;

  /// Niveau hiérarchique, utile pour trier les responsables.
  final int level;

  bool get isOfficer => level >= OrgRole.auditor.level;

  static OrgRole fromCode(String value) => OrgRole.values.firstWhere(
    (OrgRole r) => r.code == value,
    orElse: () => OrgRole.member,
  );
}
