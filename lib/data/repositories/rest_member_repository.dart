import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/organization_dto.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';

class RestMemberRepository implements MemberRepository {
  const RestMemberRepository(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<OrganizationMember>> list({
    required String organizationId,
    String query = '',
    OrgRole? role,
    MemberStatus? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final JsonMap response = await _api.get(
      ApiRoutes.members(organizationId),
      query: <String, dynamic>{
        if (query.isNotEmpty) 'query': query,
        if (role != null) 'role': role.code,
        if (status != null) 'status': status.code,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PagedResultDto.fromJson<OrganizationMember>(
      response,
      OrganizationMemberDto.fromJson,
    );
  }

  @override
  Future<OrganizationMember> byId(String memberId) async =>
      OrganizationMemberDto.fromJson(
        await _api.get(ApiRoutes.member(memberId)),
      );

  @override
  Future<OrganizationMember> create({
    required String organizationId,
    required MemberDraft draft,
    required String actorMemberId,
  }) async => OrganizationMemberDto.fromJson(
    await _api.post(
      ApiRoutes.members(organizationId),
      body: <String, dynamic>{
        ...OrganizationMemberDto.draftToJson(draft),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<OrganizationMember> update({
    required OrganizationMember member,
    required String actorMemberId,
  }) async => OrganizationMemberDto.fromJson(
    await _api.put(
      ApiRoutes.member(member.id),
      body: <String, dynamic>{
        ...OrganizationMemberDto.toJson(member),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<MemberStats> statsOf(String memberId) async =>
      MemberStatsDto.fromJson(await _api.get(ApiRoutes.memberStats(memberId)));
}
