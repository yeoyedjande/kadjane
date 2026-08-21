import 'package:kadjane/domain/entities/cash_transaction.dart';
import 'package:kadjane/domain/enums/transaction_enums.dart';

class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    this.attachmentId,
    this.tontineId,
  });

  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final DateTime date;
  final String? description;
  final String? attachmentId;
  final String? tontineId;
}

/// Solde et mouvements de caisse d'une organisation.
class TreasurySnapshot {
  const TreasurySnapshot({
    required this.balance,
    required this.inflows,
    required this.outflows,
    required this.transactions,
  });

  final double balance;
  final double inflows;
  final double outflows;
  final List<CashTransaction> transactions;
}

abstract interface class TreasuryRepository {
  Future<TreasurySnapshot> snapshot(String organizationId);

  Future<CashTransaction> record({
    required String organizationId,
    required TransactionDraft draft,
    required String actorMemberId,
  });
}
