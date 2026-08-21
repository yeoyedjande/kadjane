import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';

/// Matrice des droits par rôle.
///
/// Les écrans n'interrogent jamais le rôle directement : ils demandent une
/// permission. Chaque organisation part de la matrice par défaut définie ici et
/// peut l'ajuster depuis la console d'administration — les surcharges sont
/// alors transmises via [overrides] et s'appliquent partout, mobile compris.
class PermissionService {
  const PermissionService();

  static const Set<Permission> _memberPermissions = <Permission>{
    Permission.organizationView,
    Permission.memberView,
    Permission.tontineView,
    Permission.contributionView,
    Permission.drawView,
    Permission.payoutView,
    Permission.reminderView,
  };

  static const Set<Permission> _auditorPermissions = <Permission>{
    ..._memberPermissions,
    Permission.treasuryView,
    Permission.reportView,
    Permission.auditView,
  };

  static const Set<Permission> _treasurerPermissions = <Permission>{
    ..._auditorPermissions,
    Permission.contributionRecord,
    Permission.contributionConfirm,
    Permission.contributionCancel,
    Permission.payoutRecord,
    Permission.treasuryManage,
    Permission.reminderSend,
  };

  static const Set<Permission> _presidentPermissions = <Permission>{
    ..._auditorPermissions,
    Permission.tontineValidate,
    Permission.drawRun,
    Permission.memberInvite,
    Permission.reminderSend,
  };

  static final Set<Permission> _adminPermissions = <Permission>{
    ..._treasurerPermissions,
    ..._presidentPermissions,
    Permission.organizationEdit,
    Permission.organizationManageOfficers,
    Permission.memberCreate,
    Permission.memberEdit,
    Permission.tontineCreate,
    Permission.tontineEdit,
    Permission.drawOverride,
    Permission.drawInvalidate,
  };

  static final Map<OrgRole, Set<Permission>> _matrix =
      <OrgRole, Set<Permission>>{
        OrgRole.member: _memberPermissions,
        OrgRole.auditor: _auditorPermissions,
        OrgRole.treasurer: _treasurerPermissions,
        OrgRole.president: _presidentPermissions,
        OrgRole.admin: _adminPermissions,
      };

  /// Droits par défaut de Kadjane pour un rôle, sans surcharge.
  Set<Permission> defaultPermissionsOf(OrgRole role) {
    if (role == OrgRole.superAdmin) {
      return Permission.values.toSet();
    }
    return _matrix[role] ?? _memberPermissions;
  }

  /// Matrice par défaut complète, utilisée à la création d'une organisation.
  Map<OrgRole, Set<Permission>> get defaultMatrix => <OrgRole, Set<Permission>>{
    for (final OrgRole role in OrgRole.values) role: defaultPermissionsOf(role),
  };

  /// Permissions effectives d'un rôle, surcharges de l'organisation incluses.
  ///
  /// Le super administrateur de la plateforme conserve tous les droits : il ne
  /// peut pas se verrouiller hors de la console.
  Set<Permission> permissionsOf(
    OrgRole role, {
    Map<OrgRole, Set<Permission>>? overrides,
  }) {
    if (role == OrgRole.superAdmin) {
      return Permission.values.toSet();
    }
    return overrides?[role] ?? defaultPermissionsOf(role);
  }

  bool can(
    OrgRole role,
    Permission permission, {
    Map<OrgRole, Set<Permission>>? overrides,
  }) => permissionsOf(role, overrides: overrides).contains(permission);

  bool canAll(
    OrgRole role,
    Iterable<Permission> permissions, {
    Map<OrgRole, Set<Permission>>? overrides,
  }) => permissions.every((Permission p) => can(role, p, overrides: overrides));

  bool canAny(
    OrgRole role,
    Iterable<Permission> permissions, {
    Map<OrgRole, Set<Permission>>? overrides,
  }) => permissions.any((Permission p) => can(role, p, overrides: overrides));
}
