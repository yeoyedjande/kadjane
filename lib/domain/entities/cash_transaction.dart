import 'package:kadjane/domain/enums/transaction_enums.dart';

/// Opération de caisse d'une organisation (entrée ou sortie).
class CashTransaction {
  const CashTransaction({
    required this.id,
    required this.organizationId,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.description,
    this.attachmentId,
    this.tontineId,
    this.createdBy,
  });

  final String id;
  final String organizationId;
  final TransactionType type;
  final TransactionCategory category;

  /// Montant toujours positif : le sens est porté par [type].
  final double amount;
  final DateTime date;
  final String? description;
  final String? attachmentId;

  /// Rattachement facultatif à une tontine.
  final String? tontineId;
  final String? createdBy;
  final DateTime createdAt;

  /// Montant signé, utilisé pour calculer le solde.
  double get signedAmount => amount * type.sign;
}
