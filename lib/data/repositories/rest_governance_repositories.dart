import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/governance_dto.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/repositories/role_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';

/// Matrice des droits servie par le backend.
class RestRoleRepository implements RoleRepository {
  const RestRoleRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<RoleDefinition>> definitions(String organizationId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.roles(organizationId),
    );
    return response.map(RoleDefinitionDto.fromJson).toList(growable: false);
  }

  @override
  Future<RoleDefinition> update({
    required RoleDefinition definition,
    required String actorMemberId,
  }) async => RoleDefinitionDto.fromJson(
    await _api.put(
      ApiRoutes.role(definition.organizationId, definition.role.code),
      body: <String, dynamic>{
        ...RoleDefinitionDto.toJson(definition),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<RoleDefinition> resetToDefault({
    required String organizationId,
    required OrgRole role,
    required String actorMemberId,
  }) async => RoleDefinitionDto.fromJson(
    await _api.post(
      ApiRoutes.roleReset(organizationId, role.code),
      body: <String, dynamic>{'actorMemberId': actorMemberId},
    ),
  );
}

/// Relances pilotées par le backend (passerelles SMS / WhatsApp / e-mail).
class RestReminderRepository implements ReminderRepository {
  const RestReminderRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<DunningTarget>> targetsForCycle({
    required String tontineId,
    required String cycleId,
  }) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.cycleReminderTargets(tontineId, cycleId),
    );
    return response.map(DunningTargetDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<DunningTarget>> targetsForOrganization(
    String organizationId,
  ) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.reminderTargets(organizationId),
    );
    return response.map(DunningTargetDto.fromJson).toList(growable: false);
  }

  @override
  Future<ReminderCampaignResult> sendCampaign({
    required ReminderCampaignDraft draft,
    required String actorMemberId,
  }) async => ReminderCampaignDto.resultFromJson(
    await _api.post(
      ApiRoutes.reminderCampaigns,
      body: <String, dynamic>{
        ...ReminderCampaignDto.draftToJson(draft),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<List<ReminderCampaign>> campaignsOf(String organizationId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.organizationCampaigns(organizationId),
    );
    return response.map(ReminderCampaignDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<Reminder>> forMember({
    required String organizationId,
    required String memberId,
  }) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.memberReminders(organizationId, memberId),
    );
    return response.map(ReminderDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<Reminder>> forCycle(String cycleId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.cycleReminders(cycleId),
    );
    return response.map(ReminderDto.fromJson).toList(growable: false);
  }

  @override
  Future<void> markAsRead(String reminderId) async {
    await _api.post(ApiRoutes.reminderRead(reminderId));
  }
}
