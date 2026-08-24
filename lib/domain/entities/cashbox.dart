/// Cycle de vie d'une caisse.
enum CashboxStatus {
  open('open'),
  closed('closed'),
  suspended('suspended');

  const CashboxStatus(this.code);

  final String code;

  static CashboxStatus fromCode(String value) =>
      CashboxStatus.values.firstWhere(
        (CashboxStatus s) => s.code == value,
        orElse: () => CashboxStatus.open,
      );

  bool get acceptsTransactions => this == CashboxStatus.open;
}

/// Une caisse de l'association : un pot d'argent identifié.
///
/// Plusieurs coexistent — « Caisse principale », « Caisse sociale »,
/// « Événements » — pour que le trésorier sache où va chaque franc.
///
/// [currentBalance] vient du serveur et n'est **jamais** recalculé ici : il n'y
/// a pas de colonne de solde en base, seulement un journal dont le total fait
/// foi. Un calcul local sur une page partielle donnerait un chiffre faux.
class Cashbox {
  const Cashbox({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.currency,
    required this.openingBalance,
    required this.currentBalance,
    required this.inflows,
    required this.outflows,
    required this.status,
    required this.isDefault,
    required this.createdAt,
    this.description,
    this.closedAt,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String currency;
  final double openingBalance;
  final double currentBalance;
  final double inflows;
  final double outflows;
  final CashboxStatus status;

  /// Destinataire des encaissements dont personne n'a précisé la caisse.
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? closedAt;

  bool get isOpen => status.acceptsTransactions;
}
