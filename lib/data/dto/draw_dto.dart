import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/payout_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

class DrawParticipantDto {
  const DrawParticipantDto._();

  static DrawParticipant fromJson(JsonMap json) => DrawParticipant(
    participantId: Json.stringOr(json, 'participantId'),
    memberId: Json.stringOr(json, 'memberId'),
    displayName: Json.stringOr(json, 'displayName'),
    weight: Json.integer(json, 'weight', 1),
  );
}

class DrawSessionDto {
  const DrawSessionDto._();

  static DrawSession fromJson(JsonMap json) => DrawSession(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    tontineId: Json.stringOr(json, 'tontineId'),
    cycleId: Json.stringOr(json, 'cycleId'),
    periodLabel: Json.stringOr(json, 'periodLabel'),
    participants: Json.objects(
      json,
      'participants',
    ).map(DrawParticipantDto.fromJson).toList(growable: false),
    status: DrawStatus.fromCode(Json.stringOr(json, 'status', 'scheduled')),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    proofReference: Json.stringOr(json, 'proofReference'),
    randomSourceLabel: Json.stringOr(json, 'randomSourceLabel', 'server'),
    scheduledAt: Json.dateOrNull(json, 'scheduledAt'),
    executedAt: Json.dateOrNull(json, 'executedAt'),
    winnerParticipantId: Json.stringOrNull(json, 'winnerParticipantId'),
    winnerMemberId: Json.stringOrNull(json, 'winnerMemberId'),
    winnerName: Json.stringOrNull(json, 'winnerName'),
    launchedByMemberId: Json.stringOrNull(json, 'launchedByMemberId'),
    launchedByName: Json.stringOrNull(json, 'launchedByName'),
    seed: json['seed'] == null ? null : Json.integer(json, 'seed'),
    overrideUsed: Json.boolean(json, 'overrideUsed'),
    overrideReason: Json.stringOrNull(json, 'overrideReason'),
    closedAt: Json.dateOrNull(json, 'closedAt'),
    closeReason: Json.stringOrNull(json, 'closeReason'),
  );
}

class DrawEligibilityDto {
  const DrawEligibilityDto._();

  static DrawEligibility fromJson(JsonMap json) => DrawEligibility(
    allowed: Json.boolean(json, 'allowed'),
    reason: _reason(Json.stringOr(json, 'reason', 'none')),
    missingContributions: Json.integer(json, 'missingContributions'),
    canOverride: Json.boolean(json, 'canOverride'),
    drawOpensAt: Json.dateOrNull(json, 'drawOpensAt'),
  );

  static DrawBlockReason _reason(String value) {
    for (final DrawBlockReason reason in DrawBlockReason.values) {
      if (reason.name == value) {
        return reason;
      }
    }
    return DrawBlockReason.none;
  }
}

class BeneficiaryDto {
  const BeneficiaryDto._();

  static Beneficiary fromJson(JsonMap json) => Beneficiary(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    tontineId: Json.stringOr(json, 'tontineId'),
    cycleId: Json.stringOr(json, 'cycleId'),
    participantId: Json.stringOr(json, 'participantId'),
    memberId: Json.stringOr(json, 'memberId'),
    memberName: Json.stringOr(json, 'memberName'),
    amount: Json.amount(json, 'amount'),
    designatedAt: Json.dateOrNull(json, 'designatedAt') ?? DateTime.now(),
    source: BeneficiarySource.fromCode(
      Json.stringOr(json, 'source', 'periodic_draw'),
    ),
    avatarUrl: Json.stringOrNull(json, 'avatarUrl'),
    drawSessionId: Json.stringOrNull(json, 'drawSessionId'),
    payoutId: Json.stringOrNull(json, 'payoutId'),
  );
}

class PayoutDto {
  const PayoutDto._();

  static Payout fromJson(JsonMap json) => Payout(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    tontineId: Json.stringOr(json, 'tontineId'),
    cycleId: Json.stringOr(json, 'cycleId'),
    beneficiaryId: Json.stringOr(json, 'beneficiaryId'),
    memberId: Json.stringOr(json, 'memberId'),
    amount: Json.amount(json, 'amount'),
    status: PayoutStatus.fromCode(Json.stringOr(json, 'status', 'pending')),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    memberName: Json.stringOr(json, 'memberName'),
    method: json['method'] == null
        ? null
        : PaymentMethod.fromCode(Json.stringOr(json, 'method')),
    reference: Json.stringOrNull(json, 'reference'),
    comment: Json.stringOrNull(json, 'comment'),
    attachmentId: Json.stringOrNull(json, 'attachmentId'),
    sentAt: Json.dateOrNull(json, 'sentAt'),
    recordedBy: Json.stringOrNull(json, 'recordedBy'),
  );

  static JsonMap draftToJson(PayoutDraft draft) => <String, dynamic>{
    'beneficiaryId': draft.beneficiaryId,
    'amount': draft.amount,
    'method': draft.method.code,
    'sentAt': Json.iso(draft.sentAt),
    'reference': draft.reference,
    'comment': draft.comment,
    'attachmentId': draft.attachmentId,
    'status': draft.status.code,
  };
}
