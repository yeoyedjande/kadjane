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
    this.customPeriodDays,
    this.closedAt,
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

  /// Durée en jours quand [frequency] vaut `custom`.
  final int? customPeriodDays;
  final TontineStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? closedAt;

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
    int? customPeriodDays,
    TontineStatus? status,
    DateTime? closedAt,
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
    customPeriodDays: customPeriodDays ?? this.customPeriodDays,
    closedAt: closedAt ?? this.closedAt,
  );
}
