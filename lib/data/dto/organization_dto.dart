import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/identity_dto.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';
import 'package:kadjane/domain/repositories/organization_repository.dart';

class OrganizationSettingsDto {
  const OrganizationSettingsDto._();

  static OrganizationSettings fromJson(JsonMap? json) {
    if (json == null) {
      return const OrganizationSettings();
    }
    return OrganizationSettings(
      requireFullPaymentBeforeDraw: Json.boolean(
        json,
        'requireFullPaymentBeforeDraw',
        true,
      ),
      allowDrawOverride: Json.boolean(json, 'allowDrawOverride', true),
      latePaymentGraceDays: Json.integer(json, 'latePaymentGraceDays', 3),
      notifyBeforeDueDays: Json.integer(json, 'notifyBeforeDueDays', 3),
    );
  }

  static JsonMap toJson(OrganizationSettings settings) => <String, dynamic>{
    'requireFullPaymentBeforeDraw': settings.requireFullPaymentBeforeDraw,
    'allowDrawOverride': settings.allowDrawOverride,
    'latePaymentGraceDays': settings.latePaymentGraceDays,
    'notifyBeforeDueDays': settings.notifyBeforeDueDays,
  };
}

class OrganizationDto {
  const OrganizationDto._();

  static Organization fromJson(JsonMap json) => Organization(
    id: Json.string(json, 'id'),
    name: Json.stringOr(json, 'name'),
    currency: Currency.fromCode(Json.stringOr(json, 'currency', 'XOF')),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    description: Json.stringOrNull(json, 'description'),
    logoUrl: Json.stringOrNull(json, 'logoUrl'),
    country: Json.stringOr(json, 'country', 'CI'),
    phone: Json.stringOrNull(json, 'phone'),
    email: Json.stringOrNull(json, 'email'),
    address: Json.stringOrNull(json, 'address'),
    rules: Json.stringOrNull(json, 'rules'),
    settings: OrganizationSettingsDto.fromJson(
      Json.objectOrNull(json, 'settings'),
    ),
  );

  static JsonMap toJson(Organization organization) => <String, dynamic>{
    'id': organization.id,
    'name': organization.name,
    'description': organization.description,
    'logoUrl': organization.logoUrl,
    'currency': organization.currency.code,
    'country': organization.country,
    'phone': organization.phone,
    'email': organization.email,
    'address': organization.address,
    'rules': organization.rules,
    'settings': OrganizationSettingsDto.toJson(organization.settings),
  };

  static JsonMap draftToJson(OrganizationDraft draft) => <String, dynamic>{
    'name': draft.name,
    'currency': draft.currency.code,
    'description': draft.description,
    'country': draft.country,
    'phone': draft.phone,
    'email': draft.email,
    'address': draft.address,
  };
}

class OrganizationMemberDto {
  const OrganizationMemberDto._();

  static OrganizationMember fromJson(JsonMap json) => OrganizationMember(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    user: UserDto.fromJson(Json.object(json, 'user')),
    role: OrgRole.fromCode(Json.stringOr(json, 'role', 'member')),
    status: MemberStatus.fromCode(Json.stringOr(json, 'status', 'active')),
    joinedAt: Json.dateOrNull(json, 'joinedAt') ?? DateTime.now(),
    memberNumber: Json.stringOrNull(json, 'memberNumber'),
  );

  static JsonMap toJson(OrganizationMember member) => <String, dynamic>{
    'id': member.id,
    'organizationId': member.organizationId,
    'user': UserDto.toJson(member.user),
    'role': member.role.code,
    'status': member.status.code,
    'memberNumber': member.memberNumber,
  };

  static JsonMap draftToJson(MemberDraft draft) => <String, dynamic>{
    'firstName': draft.firstName,
    'lastName': draft.lastName,
    'phone': draft.phone,
    'role': draft.role.code,
    'email': draft.email,
    'gender': draft.gender.code,
    'birthDate': Json.iso(draft.birthDate),
    'avatarUrl': draft.avatarUrl,
    'status': draft.status.code,
  };
}

class MemberStatsDto {
  const MemberStatsDto._();

  static MemberStats fromJson(JsonMap json) => MemberStats(
    totalPaid: Json.amount(json, 'totalPaid'),
    totalReceived: Json.amount(json, 'totalReceived'),
    tontinesCount: Json.integer(json, 'tontinesCount'),
    pendingContributions: Json.integer(json, 'pendingContributions'),
    lateContributions: Json.integer(json, 'lateContributions'),
  );
}

class PagedResultDto {
  const PagedResultDto._();

  /// Attend `{ "items": [...], "page": 0, "hasMore": true, "total": 42 }`.
  static PagedResult<T> fromJson<T>(
    JsonMap json,
    T Function(JsonMap item) itemMapper,
  ) => PagedResult<T>(
    items: Json.objects(json, 'items').map(itemMapper).toList(growable: false),
    page: Json.integer(json, 'page'),
    hasMore: Json.boolean(json, 'hasMore'),
    total: Json.integer(json, 'total'),
  );
}
