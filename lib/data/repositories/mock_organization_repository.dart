import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/organization_repository.dart';

/// TODO(api): remplacer par `RestOrganizationRepository` (/organizations).
class MockOrganizationRepository implements OrganizationRepository {
  MockOrganizationRepository(this._db, this._audit);

  final MockDatabase _db;
  final AuditRepository _audit;

  @override
  Future<List<Organization>> organizationsOf(String userId) =>
      _db.withLatency(() {
        final Set<String> ids = _db.members
            .where((OrganizationMember m) => m.userId == userId)
            .map((OrganizationMember m) => m.organizationId)
            .toSet();
        return _db.organizations
            .where((Organization o) => ids.contains(o.id))
            .toList(growable: false);
      });

  @override
  Future<Organization> byId(String organizationId) =>
      _db.withLatency(() => _db.organizationById(organizationId));

  @override
  Future<Organization> create(OrganizationDraft draft, String ownerUserId) =>
      _db.withLatency(() {
        final Organization organization = Organization(
          id: _db.nextId('org'),
          name: draft.name,
          currency: draft.currency,
          createdAt: DateTime.now(),
          description: draft.description,
          country: draft.country,
          phone: draft.phone,
          email: draft.email,
          address: draft.address,
        );
        _db.organizations.add(organization);
        _db.members.add(
          OrganizationMember(
            id: _db.nextId('mbr'),
            organizationId: organization.id,
            user: _db.userById(ownerUserId),
            role: OrgRole.admin,
            joinedAt: DateTime.now(),
            memberNumber: 'M-001',
          ),
        );
        return organization;
      });

  @override
  Future<Organization> update(Organization organization) async {
    final Organization updated = await _db.withLatency(() {
      _db.replaceOrganization(organization);
      return organization;
    });
    await _audit.record(
      organizationId: updated.id,
      action: AuditAction.organizationUpdated,
      description: 'Les paramètres de l\'organisation ont été mis à jour.',
      targetType: 'organization',
      targetId: updated.id,
    );
    return updated;
  }

  @override
  Future<OrganizationMember> membershipOf({
    required String organizationId,
    required String userId,
  }) => _db.withLatency(() {
    final OrganizationMember? member = _db.memberOf(
      organizationId: organizationId,
      userId: userId,
    );
    if (member == null) {
      throw const PermissionDeniedException('not_a_member');
    }
    return member;
  });

  @override
  Future<List<OrganizationMember>> officers(String organizationId) =>
      _db.withLatency(() {
        final List<OrganizationMember> officers = _db
            .membersOf(organizationId)
            .where((OrganizationMember m) => m.role.isOfficer)
            .toList();
        officers.sort(
          (OrganizationMember a, OrganizationMember b) =>
              b.role.level.compareTo(a.role.level),
        );
        return officers;
      });
}
