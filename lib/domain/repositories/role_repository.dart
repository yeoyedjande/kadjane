import 'package:kadjane/domain/entities/member_permissions.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/enums/org_role.dart';

/// Matrice des droits d'une organisation.
abstract interface class RoleRepository {
  /// Définitions de tous les rôles de l'organisation.
  Future<List<RoleDefinition>> definitions(String organizationId);

  /// Droits du membre connecté, une entrée par appartenance.
  ///
  /// C'est la source de vérité de l'application : la matrice par rôle ne sait
  /// rien d'un rôle sur mesure, dont le membre porte l'étiquette « membre »
  /// tout en ayant des droits particuliers.
  Future<List<MemberPermissions>> myPermissions({String? organizationId});

  Future<RoleDefinition> update({
    required RoleDefinition definition,
    required String actorMemberId,
  });

  /// Rétablit les droits par défaut de Kadjane pour un rôle.
  Future<RoleDefinition> resetToDefault({
    required String organizationId,
    required OrgRole role,
    required String actorMemberId,
  });
}
