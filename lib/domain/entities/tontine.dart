import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';

/// Une tontine appartenant à une organisation.
class Tontine {
  const Tontine({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.contributionAmount,
    required this.currency,
    required this.frequency,
    required this.allocationMode,
    required this.startDate,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.dueDayOfPeriod = 5,
    this.drawDay,
    this.customPeriodDays,
    this.closedAt,
    this.requireAllContributionsBeforeDraw = true,
    this.allowDrawOverride = true,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? description;

  /// Montant dû par participant et par période.
  final double contributionAmount;
  final Currency currency;
  final TontineFrequency frequency;
  final AllocationMode allocationMode;
  final DateTime startDate;

  /// Jour d'échéance dans la période (1..28 pour le mensuel).
  final int dueDayOfPeriod;

  /// Jour de la période où le tirage s'ouvre. `null` = le jour d'échéance :
  /// on tire quand tout le monde était censé avoir cotisé.
  final int? drawDay;

  /// Jour d'ouverture effectif du tirage.
  int get drawDayOfPeriod => drawDay ?? dueDayOfPeriod;

  /// Durée en jours quand [frequency] vaut `custom`.
  final int? customPeriodDays;
  final TontineStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? closedAt;

  /// Bloque le tirage tant qu'une cotisation du cycle reste due.
  ///
  /// Règle propre à la tontine : elle est initialisée depuis les réglages de
  /// l'organisation à la création, puis vit sa vie.
  final bool requireAllContributionsBeforeDraw;

  /// Autorise un administrateur à passer outre, avec motif et trace d'audit.
  final bool allowDrawOverride;

  /// Cagnotte pour un nombre de participants donné.
  double potFor(int participantCount) => contributionAmount * participantCount;

  bool get isActive => status == TontineStatus.active;

  Tontine copyWith({
    String? name,
    String? description,
    double? contributionAmount,
    Currency? currency,
    TontineFrequency? frequency,
    AllocationMode? allocationMode,
    DateTime? startDate,
    int? dueDayOfPeriod,
    int? drawDay,
    int? customPeriodDays,
    TontineStatus? status,
    DateTime? closedAt,
    bool? requireAllContributionsBeforeDraw,
    bool? allowDrawOverride,
  }) => Tontine(
    id: id,
    organizationId: organizationId,
    name: name ?? this.name,
    contributionAmount: contributionAmount ?? this.contributionAmount,
    currency: currency ?? this.currency,
    frequency: frequency ?? this.frequency,
    allocationMode: allocationMode ?? this.allocationMode,
    startDate: startDate ?? this.startDate,
    status: status ?? this.status,
    createdAt: createdAt,
    createdBy: createdBy,
    description: description ?? this.description,
    dueDayOfPeriod: dueDayOfPeriod ?? this.dueDayOfPeriod,
    drawDay: drawDay ?? this.drawDay,
    customPeriodDays: customPeriodDays ?? this.customPeriodDays,
    closedAt: closedAt ?? this.closedAt,
    requireAllContributionsBeforeDraw:
        requireAllContributionsBeforeDraw ??
        this.requireAllContributionsBeforeDraw,
    allowDrawOverride: allowDrawOverride ?? this.allowDrawOverride,
  );
}
