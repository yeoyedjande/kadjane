import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/currency.dart';

class OrganizationDraft {
  const OrganizationDraft({
    required this.name,
    required this.currency,
    this.description,
    this.country = 'CI',
    this.phone,
    this.email,
    this.address,
  });

  final String name;
  final Currency currency;
  final String? description;
  final String country;
  final String? phone;
  final String? email;
  final String? address;
}

/// Accès aux organisations de l'utilisateur connecté.
///
/// Le cloisonnement multi-organisation est garanti ici : toutes les autres
/// requêtes passent par un `organizationId`.
abstract interface class OrganizationRepository {
  Future<List<Organization>> organizationsOf(String userId);

  Future<Organization> byId(String organizationId);

  Future<Organization> create(OrganizationDraft draft, String ownerUserId);

  Future<Organization> update(Organization organization);

  /// Appartenance (et donc rôle) de l'utilisateur dans l'organisation.
  Future<OrganizationMember> membershipOf({
    required String organizationId,
    required String userId,
  });

  /// Responsables de l'organisation (bureau).
  Future<List<OrganizationMember>> officers(String organizationId);
}
