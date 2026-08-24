import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';

/// Mappers des caisses et des campagnes de cotisation.
///
/// Aucun montant n'est recalculé ici : soldes, restes et taux de recouvrement
/// viennent du serveur, qui seul connaît le journal complet. Un calcul local
/// sur une page partielle donnerait un chiffre faux — et convaincant.

abstract final class CashboxDto {
  static Cashbox fromJson(JsonMap json) => Cashbox(
    id: Json.stringOr(json, 'id', ''),
    organizationId: Json.stringOr(json, 'organizationId', ''),
    name: Json.stringOr(json, 'name', ''),
    description: Json.stringOrNull(json, 'description'),
    currency: Json.stringOr(json, 'currency', 'XOF'),
    openingBalance: Json.amount(json, 'openingBalance'),
    currentBalance: Json.amount(json, 'currentBalance'),
    inflows: Json.amount(json, 'inflows'),
    outflows: Json.amount(json, 'outflows'),
    status: CashboxStatus.fromCode(Json.stringOr(json, 'status', 'open')),
    isDefault: Json.boolean(json, 'isDefault'),
    createdAt: Json.date(json, 'createdAt'),
    closedAt: Json.dateOrNull(json, 'closedAt'),
  );

  static JsonMap toJson({
    required String name,
    String? description,
    String currency = 'XOF',
    double openingBalance = 0,
    bool isDefault = false,
  }) => <String, dynamic>{
    'name': name,
    'description': description,
    'currency': currency,
    'openingBalance': openingBalance,
    'isDefault': isDefault,
  };
}

abstract final class CampaignSummaryDto {
  static CampaignSummary fromJson(JsonMap json) => CampaignSummary(
    membersCount: Json.integer(json, 'membersCount'),
    expected: Json.amount(json, 'expected'),
    collected: Json.amount(json, 'collected'),
    remaining: Json.amount(json, 'remaining'),
    // `null` conservé tel quel : une campagne à montant libre n'a pas de taux,
    // et le remplacer par 0 laisserait croire que personne n'a payé.
    recoveryRate: Json.doubleOrNull(json, 'recoveryRate'),
    paidCount: Json.integer(json, 'paidCount'),
    partialCount: Json.integer(json, 'partialCount'),
    pendingCount: Json.integer(json, 'pendingCount'),
    lateCount: Json.integer(json, 'lateCount'),
    exemptedCount: Json.integer(json, 'exemptedCount'),
  );
}

abstract final class CampaignPaymentDto {
  static CampaignPayment fromJson(JsonMap json) => CampaignPayment(
    id: Json.stringOr(json, 'id', ''),
    entryId: Json.stringOr(json, 'entryId', ''),
    cashTransactionId: Json.stringOrNull(json, 'cashTransactionId'),
    amount: Json.amount(json, 'amount'),
    paymentMethod: Json.stringOr(json, 'paymentMethod', 'cash'),
    reference: Json.stringOrNull(json, 'reference'),
    comment: Json.stringOrNull(json, 'comment'),
    attachmentId: Json.stringOrNull(json, 'attachmentId'),
    status: Json.stringOr(json, 'status', 'confirmed'),
    createdAt: Json.date(json, 'createdAt'),
    paidAt: Json.dateOrNull(json, 'paidAt'),
    cancelledAt: Json.dateOrNull(json, 'cancelledAt'),
    cancelReason: Json.stringOrNull(json, 'cancelReason'),
  );
}

abstract final class CampaignEntryDto {
  static CampaignEntry fromJson(JsonMap json) => CampaignEntry(
    id: Json.stringOr(json, 'id', ''),
    organizationId: Json.stringOr(json, 'organizationId', ''),
    campaignId: Json.stringOr(json, 'campaignId', ''),
    memberId: Json.stringOr(json, 'memberId', ''),
    memberName: Json.stringOr(json, 'memberName', ''),
    expectedAmount: Json.amount(json, 'expectedAmount'),
    paidAmount: Json.amount(json, 'paidAmount'),
    remainingAmount: Json.amount(json, 'remainingAmount'),
    dueDate: Json.dateOrNull(json, 'dueDate'),
    status: CampaignEntryStatus.fromCode(
      Json.stringOr(json, 'status', 'pending'),
    ),
    lastPaymentAt: Json.dateOrNull(json, 'lastPaymentAt'),
    exemptionReason: Json.stringOrNull(json, 'exemptionReason'),
    daysLate: Json.integer(json, 'daysLate'),
    campaignTitle: Json.stringOrNull(json, 'campaignTitle'),
    payments: Json.objects(json, 'payments')
        .map(CampaignPaymentDto.fromJson)
        .toList(growable: false),
  );
}

abstract final class ContributionCampaignDto {
  static ContributionCampaign fromJson(JsonMap json) => ContributionCampaign(
    id: Json.stringOr(json, 'id', ''),
    organizationId: Json.stringOr(json, 'organizationId', ''),
    tontineId: Json.stringOrNull(json, 'tontineId'),
    cashboxId: Json.stringOrNull(json, 'cashboxId'),
    title: Json.stringOr(json, 'title', ''),
    description: Json.stringOrNull(json, 'description'),
    contributionType: ContributionType.fromCode(
      Json.stringOr(json, 'contributionType', 'association'),
    ),
    amount: Json.amount(json, 'amount'),
    amountMode: AmountMode.fromCode(Json.stringOr(json, 'amountMode', 'fixed')),
    currency: Json.stringOr(json, 'currency', 'XOF'),
    startDate: Json.dateOrNull(json, 'startDate'),
    dueDate: Json.dateOrNull(json, 'dueDate'),
    mandatory: Json.boolean(json, 'mandatory'),
    penaltyEnabled: Json.boolean(json, 'penaltyEnabled'),
    penaltyAmount: Json.amount(json, 'penaltyAmount'),
    status: CampaignStatus.fromCode(Json.stringOr(json, 'status', 'active')),
    createdAt: Json.date(json, 'createdAt'),
    summary: json['summary'] is Map<String, dynamic>
        ? CampaignSummaryDto.fromJson(json['summary'] as JsonMap)
        : null,
    entries: Json.objects(json, 'entries')
        .map(CampaignEntryDto.fromJson)
        .toList(growable: false),
  );
}

abstract final class FinancialDashboardDto {
  static FinancialDashboard fromJson(JsonMap json) => FinancialDashboard(
    cashBalance: Json.amount(json, 'cashBalance'),
    cashboxes: Json.objects(json, 'cashboxes')
        .map(CashboxDto.fromJson)
        .toList(growable: false),
    monthInflows: Json.amount(json, 'monthInflows'),
    monthOutflows: Json.amount(json, 'monthOutflows'),
    expected: Json.amount(json, 'expected'),
    collected: Json.amount(json, 'collected'),
    remaining: Json.amount(json, 'remaining'),
    lateAmount: Json.amount(json, 'lateAmount'),
    recoveryRate: Json.doubleOrNull(json, 'recoveryRate'),
  );
}
