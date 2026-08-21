import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/organization_dto.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/repositories/organization_repository.dart';

class RestOrganizationRepository implements OrganizationRepository {
  const RestOrganizationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Organization>> organizationsOf(String userId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.organizations,
      query: <String, dynamic>{'userId': userId},
    );
    return response.map(OrganizationDto.fromJson).toList(growable: false);
  }

  @override
  Future<Organization> byId(String organizationId) async =>
      OrganizationDto.fromJson(
        await _api.get(ApiRoutes.organization(organizationId)),
      );

  @override
  Future<Organization> create(
    OrganizationDraft draft,
    String ownerUserId,
  ) async => OrganizationDto.fromJson(
    await _api.post(
      ApiRoutes.organizations,
      body: <String, dynamic>{
        ...OrganizationDto.draftToJson(draft),
        'ownerUserId': ownerUserId,
      },
    ),
  );

  @override
  Future<Organization> update(Organization organization) async =>
      OrganizationDto.fromJson(
        await _api.put(
          ApiRoutes.organization(organization.id),
          body: OrganizationDto.toJson(organization),
        ),
      );

  @override
  Future<OrganizationMember> membershipOf({
    required String organizationId,
    required String userId,
  }) async => OrganizationMemberDto.fromJson(
    await _api.get(
      ApiRoutes.membership(organizationId),
      query: <String, dynamic>{'userId': userId},
    ),
  );

  @override
  Future<List<OrganizationMember>> officers(String organizationId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.officers(organizationId),
    );
    return response.map(OrganizationMemberDto.fromJson).toList(growable: false);
  }
}
