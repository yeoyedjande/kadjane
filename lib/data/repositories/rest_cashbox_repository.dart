import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/data/dto/treasury_dto.dart';
import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';
import 'package:kadjane/domain/repositories/cashbox_repository.dart';

/// Caisses et cotisations servies par le backend.
class RestCashboxRepository implements CashboxRepository {
  const RestCashboxRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Cashbox>> cashboxes(String organizationId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.cashboxes(organizationId),
    );
    return response.map(CashboxDto.fromJson).toList(growable: false);
  }

  @override
  Future<Cashbox> createCashbox({
    required String organizationId,
    required String name,
    String? description,
    double openingBalance = 0,
    bool isDefault = false,
  }) async => CashboxDto.fromJson(
    await _api.post(
      ApiRoutes.cashboxes(organizationId),
      body: CashboxDto.toJson(
        name: name,
        description: description,
        openingBalance: openingBalance,
        isDefault: isDefault,
      ),
    ),
  );

  @override
  Future<void> recordMovement({
    required String cashboxId,
    required String type,
    required String category,
    required double amount,
    String? description,
    String? reference,
  }) async {
    await _api.post(
      ApiRoutes.cashboxTransactions(cashboxId),
      body: <String, dynamic>{
        'type': type,
        'category': category,
        'amount': amount,
        'description': description,
        'reference': reference,
      },
    );
  }

  @override
  Future<FinancialDashboard> financialDashboard(String organizationId) async =>
      FinancialDashboardDto.fromJson(
        await _api.get(ApiRoutes.financialDashboard(organizationId)),
      );

  @override
  Future<List<ContributionCampaign>> campaigns(
    String organizationId, {
    String? status,
    String? type,
  }) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.campaigns(organizationId),
      query: <String, dynamic>{'status': ?status, 'type': ?type},
    );
    return response
        .map(ContributionCampaignDto.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ContributionCampaign> campaign(String campaignId) async =>
      ContributionCampaignDto.fromJson(
        await _api.get(ApiRoutes.campaign(campaignId)),
      );

  @override
  Future<ContributionCampaign> createCampaign({
    required String organizationId,
    required String title,
    required ContributionType contributionType,
    required double amount,
    AmountMode amountMode = AmountMode.fixed,
    String? description,
    DateTime? dueDate,
    List<String>? memberIds,
    String? cashboxId,
    bool mandatory = true,
    bool penaltyEnabled = false,
    double penaltyAmount = 0,
  }) async => ContributionCampaignDto.fromJson(
    await _api.post(
      ApiRoutes.campaigns(organizationId),
      body: <String, dynamic>{
        'title': title,
        'description': description,
        'contributionType': contributionType.code,
        'amount': amount,
        'amountMode': amountMode.code,
        'dueDate': Json.iso(dueDate),
        // Absent : tous les membres actifs. Une liste vide serait refusée.
        'memberIds': ?memberIds,
        'cashboxId': ?cashboxId,
        'mandatory': mandatory,
        'penaltyEnabled': penaltyEnabled,
        'penaltyAmount': penaltyAmount,
      },
    ),
  );

  @override
  Future<CampaignEntry> recordPayment({
    required String entryId,
    required double amount,
    required String paymentMethod,
    String? reference,
    String? comment,
  }) async {
    final JsonMap response = await _api.post(
      ApiRoutes.campaignEntryPayments(entryId),
      body: <String, dynamic>{
        'amount': amount,
        'paymentMethod': paymentMethod,
        'reference': reference,
        'comment': comment,
      },
    );
    // La ligne renvoyée porte déjà le reste et le statut recalculés : on la
    // lit plutôt que de refaire le calcul ici.
    return CampaignEntryDto.fromJson(Json.object(response, 'entry'));
  }

  @override
  Future<CampaignEntry> exempt({
    required String entryId,
    String? reason,
  }) async => CampaignEntryDto.fromJson(
    await _api.post(
      ApiRoutes.campaignEntryExempt(entryId),
      body: <String, dynamic>{'reason': reason},
    ),
  );

  @override
  Future<List<CampaignEntry>> unpaid(String organizationId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.unpaid(organizationId),
    );
    return response.map(CampaignEntryDto.fromJson).toList(growable: false);
  }
}
