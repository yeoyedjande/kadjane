import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/cash_transaction.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/transaction_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/treasury_repository.dart';

/// TODO(api): remplacer par `RestTreasuryRepository`
/// (/organizations/{id}/transactions).
class MockTreasuryRepository implements TreasuryRepository {
  MockTreasuryRepository(this._db, this._audit);

  final MockDatabase _db;
  final AuditRepository _audit;

  @override
  Future<TreasurySnapshot> snapshot(String organizationId) =>
      _db.withLatency(() {
        final List<CashTransaction> list = _db.transactions
            .where((CashTransaction t) => t.organizationId == organizationId)
            .toList();
        list.sort(
          (CashTransaction a, CashTransaction b) => b.date.compareTo(a.date),
        );
        final double inflows = list
            .where((CashTransaction t) => t.type == TransactionType.income)
            .fold<double>(0, (double s, CashTransaction t) => s + t.amount);
        final double outflows = list
            .where((CashTransaction t) => t.type == TransactionType.expense)
            .fold<double>(0, (double s, CashTransaction t) => s + t.amount);
        return TreasurySnapshot(
          balance: inflows - outflows,
          inflows: inflows,
          outflows: outflows,
          transactions: List<CashTransaction>.unmodifiable(list),
        );
      });

  @override
  Future<CashTransaction> record({
    required String organizationId,
    required TransactionDraft draft,
    required String actorMemberId,
  }) async {
    if (draft.amount <= 0) {
      throw const ValidationException('amount_must_be_positive');
    }
    final CashTransaction transaction = await _db.withLatency(() {
      final CashTransaction created = CashTransaction(
        id: _db.nextId('trx'),
        organizationId: organizationId,
        type: draft.type,
        category: draft.category,
        amount: draft.amount,
        date: draft.date,
        description: draft.description,
        attachmentId: draft.attachmentId,
        tontineId: draft.tontineId,
        createdBy: actorMemberId,
        createdAt: DateTime.now(),
      );
      _db.transactions.add(created);
      return created;
    });

    final currency = _db.organizationById(organizationId).currency;
    await _audit.record(
      organizationId: organizationId,
      action: AuditAction.transactionRecorded,
      description:
          '${transaction.type == TransactionType.income ? 'Entrée' : 'Sortie'} '
          'de caisse de '
          '${MoneyFormatter.format(transaction.amount, currency)} enregistrée.',
      actorMemberId: actorMemberId,
      targetType: 'transaction',
      targetId: transaction.id,
      amount: transaction.signedAmount,
    );
    return transaction;
  }
}
