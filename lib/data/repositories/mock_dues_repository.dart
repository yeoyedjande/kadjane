import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/dues_repository.dart';

/// Démo hors ligne : une échéance de caisse en cours, volontairement impayée.
///
/// Le jeu de démonstration ne persiste pas de cotisations de caisse ; on en
/// fabrique une cohérente pour que l'écran ne soit pas vide.
class MockDuesRepository implements DuesRepository {
  MockDuesRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<DuesEntry>> myOutstanding(String organizationId) =>
      _db.withLatency(() {
        final DateTime now = DateTime.now();
        return <DuesEntry>[
          DuesEntry(
            id: 'dues_demo_1',
            planId: 'plan_demo',
            planName: 'Caisse de solidarité',
            memberId: 'me',
            periodLabel: 'Période en cours',
            dueDate: DateTime(now.year, now.month, 5),
            expectedAmount: 5000,
            paidAmount: 0,
            status: DateTime(now.year, now.month, 5).isBefore(now)
                ? DuesStatus.late_
                : DuesStatus.pending,
          ),
        ];
      });

  @override
  Future<List<DuesPlan>> plans(String organizationId) => _db.withLatency(
    () => <DuesPlan>[
      const DuesPlan(
        id: 'plan_demo',
        name: 'Caisse de solidarité',
        amount: 5000,
        frequency: 'monthly',
        dueDay: 5,
        status: 'active',
        unpaidCount: 1,
      ),
    ],
  );

  @override
  Future<List<DuesEntry>> entries(
    String organizationId,
    String planId, {
    int? period,
  }) => myOutstanding(organizationId);

  @override
  Future<void> recordPayment({
    required String entryId,
    required double amount,
    required PaymentMethod method,
    String? reference,
  }) => _db.withLatency(() {});
}
