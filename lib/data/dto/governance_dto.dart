import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/member_permissions.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';

class RoleDefinitionDto {
  const RoleDefinitionDto._();

  static RoleDefinition fromJson(JsonMap json) => RoleDefinition(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    role: OrgRole.fromCode(Json.stringOr(json, 'role', 'member')),
    permissions: Json.strings(
      json,
      'permissions',
    ).map(Permission.fromCode).toSet(),
    updatedAt: Json.dateOrNull(json, 'updatedAt') ?? DateTime.now(),
    isCustomized: Json.boolean(json, 'isCustomized'),
    updatedByMemberId: Json.stringOrNull(json, 'updatedByMemberId'),
  );

  static JsonMap toJson(RoleDefinition definition) => <String, dynamic>{
    'id': definition.id,
    'organizationId': definition.organizationId,
    'role': definition.role.code,
    'permissions': definition.permissions
        .map((Permission p) => p.code)
        .toList(),
    'isCustomized': definition.isCustomized,
  };
}

class ReminderDto {
  const ReminderDto._();

  static Reminder fromJson(JsonMap json) => Reminder(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    tontineId: Json.stringOr(json, 'tontineId'),
    cycleId: Json.stringOr(json, 'cycleId'),
    memberId: Json.stringOr(json, 'memberId'),
    memberName: Json.stringOr(json, 'memberName'),
    channel: ReminderChannel.fromCode(Json.stringOr(json, 'channel', 'in_app')),
    status: ReminderStatus.fromCode(Json.stringOr(json, 'status', 'queued')),
    level: ReminderLevel.fromCode(Json.stringOr(json, 'level', 'upcoming')),
    message: Json.stringOr(json, 'message'),
    amountDue: Json.amount(json, 'amountDue'),
    dueDate: Json.dateOrNull(json, 'dueDate') ?? DateTime.now(),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    campaignId: Json.stringOrNull(json, 'campaignId'),
    sentAt: Json.dateOrNull(json, 'sentAt'),
    readAt: Json.dateOrNull(json, 'readAt'),
    sentByMemberId: Json.stringOrNull(json, 'sentByMemberId'),
    sentByName: Json.stringOrNull(json, 'sentByName'),
    failureReason: Json.stringOrNull(json, 'failureReason'),
  );
}

class ReminderCampaignDto {
  const ReminderCampaignDto._();

  static ReminderCampaign fromJson(JsonMap json) => ReminderCampaign(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    tontineId: Json.stringOr(json, 'tontineId'),
    tontineName: Json.stringOr(json, 'tontineName'),
    cycleId: Json.stringOr(json, 'cycleId'),
    periodLabel: Json.stringOr(json, 'periodLabel'),
    channels: Json.strings(
      json,
      'channels',
    ).map(ReminderChannel.fromCode).toList(growable: false),
    targetCount: Json.integer(json, 'targetCount'),
    sentCount: Json.integer(json, 'sentCount'),
    totalAmountDue: Json.amount(json, 'totalAmountDue'),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    createdByMemberId: Json.stringOrNull(json, 'createdByMemberId'),
    createdByName: Json.stringOrNull(json, 'createdByName'),
  );

  static JsonMap draftToJson(ReminderCampaignDraft draft) => <String, dynamic>{
    'tontineId': draft.tontineId,
    'cycleId': draft.cycleId,
    'channels': draft.channels
        .map((ReminderChannel c) => c.code)
        .toList(growable: false),
    'messages': draft.messages,
  };

  static ReminderCampaignResult resultFromJson(JsonMap json) =>
      ReminderCampaignResult(
        campaign: fromJson(Json.object(json, 'campaign')),
        reminders: Json.objects(
          json,
          'reminders',
        ).map(ReminderDto.fromJson).toList(growable: false),
      );
}

class DunningTargetDto {
  const DunningTargetDto._();

  static DunningTarget fromJson(JsonMap json) => DunningTarget(
    memberId: Json.stringOr(json, 'memberId'),
    memberName: Json.stringOr(json, 'memberName'),
    tontineId: Json.stringOr(json, 'tontineId'),
    tontineName: Json.stringOr(json, 'tontineName'),
    cycleId: Json.stringOr(json, 'cycleId'),
    periodStart: Json.dateOrNull(json, 'periodStart') ?? DateTime.now(),
    dueDate: Json.dateOrNull(json, 'dueDate') ?? DateTime.now(),
    amountDue: Json.amount(json, 'amountDue'),
    level: ReminderLevel.fromCode(Json.stringOr(json, 'level', 'upcoming')),
    daysLate: Json.integer(json, 'daysLate'),
    reminderCount: Json.integer(json, 'reminderCount'),
    lastReminderAt: Json.dateOrNull(json, 'lastReminderAt'),
  );
}

/// Droits du membre connecté, servis par `/me/permissions`.
abstract final class MemberPermissionsDto {
  static MemberPermissions fromJson(JsonMap json) => MemberPermissions(
    organizationId: Json.stringOr(json, 'organizationId', ''),
    memberId: Json.stringOr(json, 'memberId', ''),
    roleCode: Json.stringOr(json, 'role', 'member'),
    roleName: Json.stringOr(json, 'roleName', ''),
    roleId: Json.stringOrNull(json, 'roleId'),
    // Un code inconnu de cette version du client est ignoré plutôt que
    // rabattu sur un autre droit : mieux vaut masquer un bouton que d'en
    // afficher un que le backend refusera.
    permissions: Json.strings(json, 'permissions')
        .map(Permission.tryFromCode)
        .whereType<Permission>()
        .toSet(),
  );
}
