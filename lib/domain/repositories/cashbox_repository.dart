import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';

/// Caisses et cotisations de l'association.
///
/// Les cotisations de tontine ne passent pas par ici : elles alimentent la
/// cagnotte d'un cycle, pas la caisse de l'association.
abstract interface class CashboxRepository {
  Future<List<Cashbox>> cashboxes(String organizationId);

  Future<Cashbox> createCashbox({
    required String organizationId,
    required String name,
    String? description,
    double openingBalance = 0,
    bool isDefault = false,
  });

  /// Entrée ou sortie saisie à la main. Les encaissements de cotisation, eux,
  /// sont engendrés par le règlement : ils ne se saisissent pas deux fois.
  Future<void> recordMovement({
    required String cashboxId,
    required String type,
    required String category,
    required double amount,
    String? description,
    String? reference,
  });

  Future<FinancialDashboard> financialDashboard(String organizationId);

  Future<List<ContributionCampaign>> campaigns(
    String organizationId, {
    String? status,
    String? type,
  });

  Future<ContributionCampaign> campaign(String campaignId);

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
  });

  /// Enregistre un règlement.
  ///
  /// Le serveur en tire toutes les conséquences dans une seule transaction :
  /// suivi du membre, reste, statut, écriture de caisse, solde, audit et
  /// notification. Le client ne recalcule rien, il relit.
  Future<CampaignEntry> recordPayment({
    required String entryId,
    required double amount,
    required String paymentMethod,
    String? reference,
    String? comment,
  });

  Future<CampaignEntry> exempt({required String entryId, String? reason});

  /// Ce qui reste dû, exemptions exclues.
  Future<List<CampaignEntry>> unpaid(String organizationId);
}
