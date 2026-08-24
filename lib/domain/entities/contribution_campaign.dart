import 'package:kadjane/domain/entities/cashbox.dart';

/// Nature d'une cotisation — elle décide d'où va l'argent.
enum ContributionType {
  /// Alimente la cagnotte d'un cycle, pas la caisse de l'association.
  tontine('tontine'),
  association('association'),
  exceptional('exceptional'),
  voluntary('voluntary');

  const ContributionType(this.code);

  final String code;

  static ContributionType fromCode(String value) =>
      ContributionType.values.firstWhere(
        (ContributionType t) => t.code == value,
        orElse: () => ContributionType.association,
      );

  bool get feedsCashbox => this != ContributionType.tontine;
}

/// `free` : chacun donne ce qu'il veut — l'attendu n'a pas de sens.
enum AmountMode {
  fixed('fixed'),
  free('free');

  const AmountMode(this.code);

  final String code;

  static AmountMode fromCode(String value) => AmountMode.values.firstWhere(
    (AmountMode m) => m.code == value,
    orElse: () => AmountMode.fixed,
  );
}

enum CampaignStatus {
  draft('draft'),
  active('active'),
  closed('closed'),
  cancelled('cancelled');

  const CampaignStatus(this.code);

  final String code;

  static CampaignStatus fromCode(String value) =>
      CampaignStatus.values.firstWhere(
        (CampaignStatus s) => s.code == value,
        orElse: () => CampaignStatus.active,
      );

  bool get acceptsPayments => this == CampaignStatus.active;
}

/// État individuel d'un membre pour une cotisation.
enum CampaignEntryStatus {
  pending('pending'),
  partial('partial'),
  paid('paid'),
  late_('late'),

  /// Dispensé : la ligne sort de l'attendu, ce n'est pas un impayé.
  exempted('exempted'),
  cancelled('cancelled');

  const CampaignEntryStatus(this.code);

  final String code;

  static CampaignEntryStatus fromCode(String value) =>
      CampaignEntryStatus.values.firstWhere(
        (CampaignEntryStatus s) => s.code == value,
        orElse: () => CampaignEntryStatus.pending,
      );

  bool get isSettled =>
      this == CampaignEntryStatus.paid ||
      this == CampaignEntryStatus.exempted ||
      this == CampaignEntryStatus.cancelled;

  /// Vrai si la ligne pèse encore sur l'attendu.
  bool get isOwed =>
      this != CampaignEntryStatus.exempted &&
      this != CampaignEntryStatus.cancelled;
}

/// Agrégats d'une cotisation — quatre nombres qui ne se confondent pas.
class CampaignSummary {
  const CampaignSummary({
    required this.membersCount,
    required this.expected,
    required this.collected,
    required this.remaining,
    required this.paidCount,
    required this.partialCount,
    required this.pendingCount,
    required this.lateCount,
    required this.exemptedCount,
    this.recoveryRate,
  });

  final int membersCount;

  /// Ce que l'association attend.
  final double expected;

  /// Ce qu'elle a réellement encaissé.
  final double collected;
  final double remaining;

  /// `null` pour une cotisation à montant libre : ni 0 % ni 100 % ne diraient
  /// la vérité, faute d'attendu.
  final double? recoveryRate;

  final int paidCount;
  final int partialCount;
  final int pendingCount;
  final int lateCount;
  final int exemptedCount;
}

/// Une cotisation lancée auprès de membres désignés.
///
/// « Cotisation mensuelle de fonctionnement », « Soutien mariage de M. X »,
/// « Participation volontaire à la sortie » : même structure, trois natures.
///
/// Une cotisation est un **engagement**, pas de l'argent : la caisse
/// n'augmente que lorsqu'un paiement est enregistré.
class ContributionCampaign {
  const ContributionCampaign({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.contributionType,
    required this.amount,
    required this.amountMode,
    required this.currency,
    required this.status,
    required this.mandatory,
    required this.createdAt,
    this.description,
    this.cashboxId,
    this.tontineId,
    this.startDate,
    this.dueDate,
    this.penaltyEnabled = false,
    this.penaltyAmount = 0,
    this.summary,
    this.entries = const <CampaignEntry>[],
  });

  final String id;
  final String organizationId;
  final String? tontineId;
  final String? cashboxId;
  final String title;
  final String? description;
  final ContributionType contributionType;
  final double amount;
  final AmountMode amountMode;
  final String currency;
  final DateTime? startDate;
  final DateTime? dueDate;
  final bool mandatory;
  final bool penaltyEnabled;
  final double penaltyAmount;
  final CampaignStatus status;
  final DateTime createdAt;
  final CampaignSummary? summary;
  final List<CampaignEntry> entries;

  bool get hasExpectedAmount => amountMode == AmountMode.fixed;
}

/// Ce qu'un membre désigné doit pour une cotisation.
class CampaignEntry {
  const CampaignEntry({
    required this.id,
    required this.organizationId,
    required this.campaignId,
    required this.memberId,
    required this.memberName,
    required this.expectedAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.daysLate,
    this.dueDate,
    this.lastPaymentAt,
    this.exemptionReason,
    this.campaignTitle,
    this.payments = const <CampaignPayment>[],
  });

  final String id;
  final String organizationId;
  final String campaignId;
  final String memberId;
  final String memberName;
  final double expectedAmount;
  final double paidAmount;
  final double remainingAmount;
  final DateTime? dueDate;
  final CampaignEntryStatus status;
  final DateTime? lastPaymentAt;
  final String? exemptionReason;
  final int daysLate;

  /// Renseigné dans la vue « Impayés », où la cotisation n'est pas le contexte.
  final String? campaignTitle;
  final List<CampaignPayment> payments;
}

/// Un règlement reçu d'un membre.
///
/// Les paiements partiels sont la norme : deux versements restent deux lignes
/// distinctes, jamais fusionnées.
class CampaignPayment {
  const CampaignPayment({
    required this.id,
    required this.entryId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.reference,
    this.comment,
    this.attachmentId,
    this.paidAt,
    this.cancelledAt,
    this.cancelReason,
    this.cashTransactionId,
  });

  final String id;
  final String entryId;

  /// Écriture de caisse engendrée par ce règlement : c'est ce lien qui
  /// interdit la double saisie.
  final String? cashTransactionId;
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String? comment;
  final String? attachmentId;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  bool get isConfirmed => status == 'confirmed';
}

/// Tableau de bord du trésorier.
class FinancialDashboard {
  const FinancialDashboard({
    required this.cashBalance,
    required this.cashboxes,
    required this.monthInflows,
    required this.monthOutflows,
    required this.expected,
    required this.collected,
    required this.remaining,
    required this.lateAmount,
    this.recoveryRate,
  });

  /// Somme des soldes de caisse : ce que l'association détient réellement.
  final double cashBalance;
  final List<Cashbox> cashboxes;
  final double monthInflows;
  final double monthOutflows;

  /// Attendu, encaissé, reste : trois nombres distincts du solde ci-dessus.
  final double expected;
  final double collected;
  final double remaining;
  final double lateAmount;
  final double? recoveryRate;
}
