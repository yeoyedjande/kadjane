/// État d'une échéance de caisse.
///
/// Enum dédié : `ContributionStatus` décrit l'état d'un **paiement**
/// (confirmé, rejeté…), pas celui d'une somme due.
enum DuesStatus {
  pending('pending'),
  partial('partial'),
  paid('paid'),
  late_('late'),
  cancelled('cancelled');

  const DuesStatus(this.code);

  final String code;

  static DuesStatus fromCode(String value) => DuesStatus.values.firstWhere(
    (DuesStatus s) => s.code == value,
    orElse: () => DuesStatus.pending,
  );

  bool get isSettled => this == DuesStatus.paid || this == DuesStatus.cancelled;
}

/// Ce qu'un membre doit à la caisse de l'association pour une période.
///
/// À ne pas confondre avec une cotisation de tontine : la caisse n'est pas
/// redistribuée. Elle finance le fonctionnement de l'association, et le
/// trésorier en garde le produit.
class DuesEntry {
  const DuesEntry({
    required this.id,
    required this.planId,
    required this.memberId,
    required this.periodLabel,
    required this.dueDate,
    required this.expectedAmount,
    required this.paidAmount,
    required this.status,
    this.planName = '',
    this.memberName = '',
  });

  final String id;
  final String planId;

  /// Nom de la cotisation, par exemple « Caisse de solidarité ».
  final String planName;
  final String memberId;

  /// Nom affichable du membre. Vide sur `/me/dues` : le membre se connaît.
  final String memberName;

  /// Période concernée, déjà mise en forme par le serveur (« Août 2026 »).
  final String periodLabel;
  final DateTime dueDate;
  final double expectedAmount;
  final double paidAmount;
  final DuesStatus status;

  double get remainingAmount {
    final double rest = expectedAmount - paidAmount;
    return rest > 0 ? rest : 0;
  }

  bool get isSettled => status.isSettled;

  bool get isLate => status == DuesStatus.late_;
}

/// Une cotisation périodique définie par l'organisation.
class DuesPlan {
  const DuesPlan({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.dueDay,
    required this.status,
    this.description,
    this.unpaidCount = 0,
    this.collectedTotal = 0,
    this.outstandingTotal = 0,
  });

  final String id;
  final String name;
  final double amount;

  /// Code de périodicité renvoyé par le serveur (`monthly`, `weekly`…).
  final String frequency;
  final int dueDay;

  /// `active`, `paused` ou `closed`. Un plan non actif n'engendre plus rien.
  final String status;
  final String? description;

  // Synthèse calculée par le serveur, pour éviter un second appel.
  final int unpaidCount;
  final double collectedTotal;
  final double outstandingTotal;

  bool get isActive => status == 'active';
}
