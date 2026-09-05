import 'package:kadjane/domain/enums/tontine_enums.dart';

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

/// Cycle de vie d'une cotisation périodique.
///
/// Un plan suspendu n'engendre plus d'échéance mais garde ses impayés : on ne
/// solde jamais une dette en changeant un statut.
enum DuesPlanStatus {
  active('active'),
  paused('paused'),
  closed('closed');

  const DuesPlanStatus(this.code);

  final String code;

  static DuesPlanStatus fromCode(String value) =>
      DuesPlanStatus.values.firstWhere(
        (DuesPlanStatus s) => s.code == value,
        orElse: () => DuesPlanStatus.active,
      );
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
    this.sequenceNumber = 1,
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

  /// Rang de la période dans le plan, à partir de 1. Sert au filtre par
  /// période : le libellé, lui, est de la mise en forme.
  final int sequenceNumber;

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

  DuesEntry copyWith({double? paidAmount, DuesStatus? status}) => DuesEntry(
    id: id,
    planId: planId,
    planName: planName,
    memberId: memberId,
    memberName: memberName,
    sequenceNumber: sequenceNumber,
    periodLabel: periodLabel,
    dueDate: dueDate,
    expectedAmount: expectedAmount,
    paidAmount: paidAmount ?? this.paidAmount,
    status: status ?? this.status,
  );
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
    this.organizationId = '',
    this.currency = 'XOF',
    this.customPeriodDays,
    this.startDate,
    this.description,
    this.unpaidCount = 0,
    this.collectedTotal = 0,
    this.outstandingTotal = 0,
  });

  final String id;

  /// Organisation propriétaire. Vide quand le serveur ne la joint pas : le
  /// plan est alors déjà lu dans le contexte d'une organisation connue.
  final String organizationId;
  final String name;
  final double amount;
  final String currency;

  /// Périodicité des échéances. Partagée avec les tontines : la mécanique de
  /// découpage en périodes est la même, seule la finalité change.
  final TontineFrequency frequency;

  /// Longueur de la période quand [frequency] vaut `custom`.
  final int? customPeriodDays;

  /// Rang du jour d'échéance dans la période — le 5 du mois, par défaut.
  final int dueDay;

  /// Début de la première période. `null` tant que le serveur ne l'a pas fixé.
  final DateTime? startDate;

  final DuesPlanStatus status;
  final String? description;

  // Synthèse calculée par le serveur, pour éviter un second appel.
  final int unpaidCount;
  final double collectedTotal;
  final double outstandingTotal;

  bool get isActive => status == DuesPlanStatus.active;

  /// Un plan clos ne se rouvre pas : les échéances passées sont figées.
  bool get isClosed => status == DuesPlanStatus.closed;

  DuesPlan copyWith({
    String? name,
    double? amount,
    String? description,
    int? dueDay,
    DuesPlanStatus? status,
    int? unpaidCount,
    double? collectedTotal,
    double? outstandingTotal,
  }) => DuesPlan(
    id: id,
    organizationId: organizationId,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    currency: currency,
    frequency: frequency,
    customPeriodDays: customPeriodDays,
    dueDay: dueDay ?? this.dueDay,
    startDate: startDate,
    status: status ?? this.status,
    description: description ?? this.description,
    unpaidCount: unpaidCount ?? this.unpaidCount,
    collectedTotal: collectedTotal ?? this.collectedTotal,
    outstandingTotal: outstandingTotal ?? this.outstandingTotal,
  );
}

/// Saisie d'une nouvelle cotisation périodique.
///
/// Objet de transport : il n'a pas d'identité tant que le serveur ne l'a pas
/// accepté.
class DuesPlanDraft {
  const DuesPlanDraft({
    required this.name,
    required this.amount,
    this.frequency = TontineFrequency.monthly,
    this.dueDay = 5,
    this.customPeriodDays,
    this.startDate,
    this.description,
    this.currency = 'XOF',
  });

  final String name;
  final double amount;
  final TontineFrequency frequency;
  final int dueDay;
  final int? customPeriodDays;
  final DateTime? startDate;
  final String? description;
  final String currency;
}
