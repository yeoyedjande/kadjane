import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';

class TontineDto {
  const TontineDto._();

  static Tontine fromJson(JsonMap json) => Tontine(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    name: Json.stringOr(json, 'name'),
    contributionAmount: Json.amount(json, 'contributionAmount'),
    currency: Currency.fromCode(Json.stringOr(json, 'currency', 'XOF')),
    frequency: TontineFrequency.fromCode(
      Json.stringOr(json, 'frequency', 'monthly'),
    ),
    allocationMode: AllocationMode.fromCode(
      Json.stringOr(json, 'allocationMode', 'monthly_draw'),
    ),
    startDate: Json.dateOrNull(json, 'startDate') ?? DateTime.now(),
    status: TontineStatus.fromCode(Json.stringOr(json, 'status', 'draft')),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    createdBy: Json.stringOr(json, 'createdBy'),
    description: Json.stringOrNull(json, 'description'),
    dueDayOfPeriod: Json.integer(json, 'dueDayOfPeriod', 5),
    customPeriodDays: json['customPeriodDays'] == null
        ? null
        : Json.integer(json, 'customPeriodDays'),
    closedAt: Json.dateOrNull(json, 'closedAt'),
  );

  static JsonMap toJson(Tontine tontine) => <String, dynamic>{
    'id': tontine.id,
    'organizationId': tontine.organizationId,
    'name': tontine.name,
    'description': tontine.description,
    'contributionAmount': tontine.contributionAmount,
    'currency': tontine.currency.code,
    'frequency': tontine.frequency.code,
    'allocationMode': tontine.allocationMode.code,
    'startDate': Json.iso(tontine.startDate),
    'dueDayOfPeriod': tontine.dueDayOfPeriod,
    'customPeriodDays': tontine.customPeriodDays,
    'status': tontine.status.code,
  };

  static JsonMap draftToJson(TontineDraft draft) => <String, dynamic>{
    'name': draft.name,
    'description': draft.description,
    'contributionAmount': draft.contributionAmount,
    'currency': draft.currency.code,
    'frequency': draft.frequency.code,
    'allocationMode': draft.allocationMode.code,
    'startDate': Json.iso(draft.startDate),
    'dueDayOfPeriod': draft.dueDayOfPeriod,
    'customPeriodDays': draft.customPeriodDays,
    'memberIds': draft.memberIds,
    'manualOrder': draft.manualOrder,
  };
}

class TontineParticipantDto {
  const TontineParticipantDto._();

  static TontineParticipant fromJson(JsonMap json) => TontineParticipant(
    id: Json.string(json, 'id'),
    tontineId: Json.stringOr(json, 'tontineId'),
    memberId: Json.stringOr(json, 'memberId'),
    displayName: Json.stringOr(json, 'displayName'),
    joinedAt: Json.dateOrNull(json, 'joinedAt') ?? DateTime.now(),
    avatarUrl: Json.stringOrNull(json, 'avatarUrl'),
    isEligibleForDraw: Json.boolean(json, 'isEligibleForDraw', true),
    hasReceivedPot: Json.boolean(json, 'hasReceivedPot'),
    receivedCycleId: Json.stringOrNull(json, 'receivedCycleId'),
    receivedPeriodStart: Json.dateOrNull(json, 'receivedPeriodStart'),
    orderPosition: json['orderPosition'] == null
        ? null
        : Json.integer(json, 'orderPosition'),
    isActive: Json.boolean(json, 'isActive', true),
  );
}

class TontineCycleDto {
  const TontineCycleDto._();

  static TontineCycle fromJson(JsonMap json) => TontineCycle(
    id: Json.string(json, 'id'),
    tontineId: Json.stringOr(json, 'tontineId'),
    index: Json.integer(json, 'index', 1),
    periodStart: Json.dateOrNull(json, 'periodStart') ?? DateTime.now(),
    periodEnd: Json.dateOrNull(json, 'periodEnd') ?? DateTime.now(),
    dueDate: Json.dateOrNull(json, 'dueDate') ?? DateTime.now(),
    expectedAmount: Json.amount(json, 'expectedAmount'),
    status: CycleStatus.fromCode(Json.stringOr(json, 'status', 'upcoming')),
    beneficiaryParticipantId: Json.stringOrNull(
      json,
      'beneficiaryParticipantId',
    ),
    beneficiaryId: Json.stringOrNull(json, 'beneficiaryId'),
    drawSessionId: Json.stringOrNull(json, 'drawSessionId'),
    payoutId: Json.stringOrNull(json, 'payoutId'),
    drawScheduledAt: Json.dateOrNull(json, 'drawScheduledAt'),
  );
}

class TontineSummaryDto {
  const TontineSummaryDto._();

  /// Attend la tontine et ses agrégats déjà calculés côté serveur.
  static TontineSummary fromJson(JsonMap json) => TontineSummary(
    tontine: TontineDto.fromJson(Json.object(json, 'tontine')),
    participantCount: Json.integer(json, 'participantCount'),
    completedCycles: Json.integer(json, 'completedCycles'),
    totalCycles: Json.integer(json, 'totalCycles'),
    collectedCurrentCycle: Json.amount(json, 'collectedCurrentCycle'),
    expectedCurrentCycle: Json.amount(json, 'expectedCurrentCycle'),
    currentCycle: Json.objectOrNull(json, 'currentCycle') == null
        ? null
        : TontineCycleDto.fromJson(Json.object(json, 'currentCycle')),
    currentBeneficiaryName: Json.stringOrNull(json, 'currentBeneficiaryName'),
    previousBeneficiaryName: Json.stringOrNull(json, 'previousBeneficiaryName'),
  );
}

class ContributionDto {
  const ContributionDto._();

  static Contribution fromJson(JsonMap json) => Contribution(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    tontineId: Json.stringOr(json, 'tontineId'),
    cycleId: Json.stringOr(json, 'cycleId'),
    memberId: Json.stringOr(json, 'memberId'),
    amount: Json.amount(json, 'amount'),
    status: ContributionStatus.fromCode(
      Json.stringOr(json, 'status', 'pending'),
    ),
    recordedAt: Json.dateOrNull(json, 'recordedAt') ?? DateTime.now(),
    memberName: Json.stringOr(json, 'memberName'),
    method: json['method'] == null
        ? null
        : PaymentMethod.fromCode(Json.stringOr(json, 'method')),
    reference: Json.stringOrNull(json, 'reference'),
    comment: Json.stringOrNull(json, 'comment'),
    attachmentId: Json.stringOrNull(json, 'attachmentId'),
    paidAt: Json.dateOrNull(json, 'paidAt'),
    recordedBy: Json.stringOrNull(json, 'recordedBy'),
    cancelledAt: Json.dateOrNull(json, 'cancelledAt'),
    cancelReason: Json.stringOrNull(json, 'cancelReason'),
  );

  static JsonMap draftToJson(ContributionDraft draft) => <String, dynamic>{
    'tontineId': draft.tontineId,
    'cycleId': draft.cycleId,
    'memberId': draft.memberId,
    'amount': draft.amount,
    'method': draft.method.code,
    'status': draft.status.code,
    'paidAt': Json.iso(draft.paidAt),
    'reference': draft.reference,
    'comment': draft.comment,
    'attachmentId': draft.attachmentId,
  };
}

class ContributionSlotDto {
  const ContributionSlotDto._();

  static ContributionSlot fromJson(JsonMap json) => ContributionSlot(
    memberId: Json.stringOr(json, 'memberId'),
    memberName: Json.stringOr(json, 'memberName'),
    expectedAmount: Json.amount(json, 'expectedAmount'),
    avatarUrl: Json.stringOrNull(json, 'avatarUrl'),
    contribution: Json.objectOrNull(json, 'contribution') == null
        ? null
        : ContributionDto.fromJson(Json.object(json, 'contribution')),
  );
}
