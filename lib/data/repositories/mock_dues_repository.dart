import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/utils/period_label.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/dues_repository.dart';
import 'package:kadjane/domain/services/period_calculator.dart';

/// Caisse de l'association en mode démonstration.
///
/// Reproduit la règle du backend : les échéances ne sont pas posées à l'avance,
/// elles sont engendrées à la lecture pour toutes les périodes écoulées
/// ([_ensureEntries]). Consulter une cotisation suffit donc à faire apparaître
/// le mois courant.
class MockDuesRepository implements DuesRepository {
  MockDuesRepository(this._db, this._audit, this._store);

  final MockDatabase _db;
  final AuditRepository _audit;
  final KeyValueStore _store;

  static const PeriodCalculator _periods = PeriodCalculator();

  @override
  Future<List<DuesEntry>> myOutstanding(String organizationId) async {
    final String? userId = await _store.getString(StorageKeys.currentUserId);
    return _db.withLatency(() {
      final OrganizationMember? me = userId == null
          ? null
          : _db.memberOf(organizationId: organizationId, userId: userId);
      if (me == null) {
        return const <DuesEntry>[];
      }
      for (final DuesPlan plan in _db.duesPlansOf(organizationId)) {
        _ensureEntries(plan);
      }
      final List<DuesEntry> mine = _db.duesEntries
          .where(
            (DuesEntry e) =>
                e.memberId == me.id &&
                !e.isSettled &&
                _belongsTo(e, organizationId),
          )
          .toList();
      mine.sort((DuesEntry a, DuesEntry b) => a.dueDate.compareTo(b.dueDate));
      return mine;
    });
  }

  @override
  Future<List<DuesPlan>> plans(String organizationId) => _db.withLatency(() {
    for (final DuesPlan plan in _db.duesPlansOf(organizationId)) {
      _ensureEntries(plan);
      _db.replaceDuesPlan(_withSummary(plan));
    }
    return _db.duesPlansOf(organizationId);
  });

  @override
  Future<List<DuesEntry>> entries(
    String organizationId,
    String planId, {
    int? period,
  }) => _db.withLatency(() {
    final DuesPlan plan = _plan(organizationId, planId);
    _ensureEntries(plan);
    final List<DuesEntry> rows = _db.duesEntries
        .where(
          (DuesEntry e) =>
              e.planId == plan.id &&
              (period == null || e.sequenceNumber == period),
        )
        .toList();
    rows.sort((DuesEntry a, DuesEntry b) {
      final int byPeriod = b.sequenceNumber.compareTo(a.sequenceNumber);
      return byPeriod != 0 ? byPeriod : a.memberName.compareTo(b.memberName);
    });
    return rows;
  });

  @override
  Future<DuesPlan> createPlan(String organizationId, DuesPlanDraft draft) =>
      _db.withLatency(() {
        final String name = draft.name.trim();
        if (name.isEmpty) {
          throw const ValidationException('name_required');
        }
        if (draft.amount <= 0) {
          throw const ValidationException('invalid_amount');
        }
        // Même garde que le serveur : deux cotisations homonymes rendraient
        // les relances illisibles.
        if (_isNameTaken(organizationId, name, null)) {
          throw const BusinessRuleException(
            'dues_plan_exists',
            code: 'dues_plan_exists',
          );
        }

        final DateTime start = draft.startDate ?? DateTime.now();
        final DuesPlan plan = DuesPlan(
          id: _db.nextId('dpl'),
          organizationId: organizationId,
          name: name,
          description: draft.description,
          amount: draft.amount,
          currency: draft.currency,
          frequency: draft.frequency,
          customPeriodDays: draft.customPeriodDays,
          dueDay: draft.dueDay,
          startDate: DateTime(start.year, start.month),
          status: DuesPlanStatus.active,
        );
        _db.duesPlans.add(plan);
        _ensureEntries(plan);
        _db.replaceDuesPlan(_withSummary(plan));

        _trace(
          organizationId: organizationId,
          action: AuditAction.duesPlanCreated,
          description: 'Cotisation « ${plan.name} » créée.',
          targetId: plan.id,
          amount: plan.amount,
        );
        return _db.duesPlanById(plan.id);
      });

  @override
  Future<DuesPlan> updatePlan(
    String organizationId,
    String planId, {
    String? name,
    double? amount,
    String? description,
    int? dueDay,
    DuesPlanStatus? status,
  }) => _db.withLatency(() {
    final DuesPlan plan = _plan(organizationId, planId);
    if (amount != null && amount <= 0) {
      throw const ValidationException('invalid_amount');
    }
    final String? trimmed = name?.trim();
    if (trimmed != null && trimmed.isEmpty) {
      throw const ValidationException('name_required');
    }
    if (trimmed != null && _isNameTaken(organizationId, trimmed, plan.id)) {
      throw const BusinessRuleException(
        'dues_plan_exists',
        code: 'dues_plan_exists',
      );
    }

    // Un nouveau montant ne vaut que pour les périodes à venir : les échéances
    // déjà engendrées gardent le leur, sous peine de fausser les comptes.
    _db.replaceDuesPlan(
      plan.copyWith(
        name: trimmed,
        amount: amount,
        description: description,
        dueDay: dueDay,
        status: status,
      ),
    );
    final DuesPlan updated = _db.duesPlanById(plan.id);
    _ensureEntries(updated);
    _db.replaceDuesPlan(_withSummary(updated));

    _trace(
      organizationId: organizationId,
      action: AuditAction.duesPlanUpdated,
      description: 'Cotisation « ${updated.name} » modifiée.',
      targetId: plan.id,
    );
    return _db.duesPlanById(plan.id);
  });

  @override
  Future<void> recordPayment({
    required String entryId,
    required double amount,
    required PaymentMethod method,
    String? reference,
    DateTime? paidAt,
  }) => _db.withLatency(() {
    if (amount <= 0) {
      throw const ValidationException('invalid_amount');
    }
    final int index = _db.duesEntries.indexWhere(
      (DuesEntry e) => e.id == entryId,
    );
    if (index == -1) {
      throw NotFoundException('dues_entry:$entryId');
    }

    final DuesEntry entry = _db.duesEntries[index];
    final double paid = entry.paidAmount + amount;
    // Comparaison tolérante : un montant saisi à l'unité près ne doit pas
    // laisser une échéance « partielle » pour un franc d'arrondi.
    final bool settled = paid >= entry.expectedAmount - 0.001;
    _db.replaceDuesEntry(
      entry.copyWith(
        paidAmount: paid,
        status: settled ? DuesStatus.paid : DuesStatus.partial,
      ),
    );

    final DuesPlan plan = _db.duesPlanById(entry.planId);
    _db.replaceDuesPlan(_withSummary(plan));
    _trace(
      organizationId: plan.organizationId,
      action: AuditAction.duesPaymentRecorded,
      description:
          'Règlement de caisse de ${entry.memberName} '
          '(${entry.periodLabel}).',
      targetId: entry.id,
      amount: amount,
    );
  });

  // --- Interne --------------------------------------------------------------

  DuesPlan _plan(String organizationId, String planId) {
    final DuesPlan plan = _db.duesPlanById(planId);
    // Cloisonnement multi-organisation : un identifiant étranger est traité
    // comme inexistant, jamais comme un refus — cela révélerait son existence.
    if (plan.organizationId != organizationId) {
      throw NotFoundException('dues_plan:$planId');
    }
    return plan;
  }

  bool _isNameTaken(String organizationId, String name, String? exceptId) {
    final String needle = name.toLowerCase();
    return _db
        .duesPlansOf(organizationId)
        .any(
          (DuesPlan p) => p.id != exceptId && p.name.toLowerCase() == needle,
        );
  }

  bool _belongsTo(DuesEntry entry, String organizationId) {
    for (final DuesPlan plan in _db.duesPlans) {
      if (plan.id == entry.planId) {
        return plan.organizationId == organizationId;
      }
    }
    return false;
  }

  /// Engendre les échéances manquantes jusqu'à la période en cours.
  ///
  /// Idempotent : une échéance déjà présente pour (plan, membre, période) n'est
  /// jamais recréée. Un plan suspendu ou clos n'en produit plus aucune, mais
  /// garde celles déjà dues.
  void _ensureEntries(DuesPlan plan) {
    if (!plan.isActive) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime start = plan.startDate ?? now;
    final List<OrganizationMember> members = _db
        .membersOf(plan.organizationId)
        .where((OrganizationMember m) => m.isActive)
        .toList(growable: false);

    // Garde-fou : une date de début très ancienne ne doit pas engendrer une
    // liste sans fin. Cinq ans de mensualités suffisent à la démonstration.
    for (int index = 0; index < 60; index++) {
      final PeriodBounds bounds = _periods.boundsFor(
        startDate: start,
        frequency: plan.frequency,
        index: index,
        dueDayOfPeriod: plan.dueDay,
        customPeriodDays: plan.customPeriodDays,
      );
      // On s'arrête à la période en cours : la caisse ne réclame pas d'avance.
      if (bounds.start.isAfter(now)) {
        break;
      }
      final int sequence = index + 1;
      for (final OrganizationMember member in members) {
        final bool exists = _db.duesEntries.any(
          (DuesEntry e) =>
              e.planId == plan.id &&
              e.memberId == member.id &&
              e.sequenceNumber == sequence,
        );
        if (exists) {
          continue;
        }
        _db.duesEntries.add(
          DuesEntry(
            id: _db.nextId('den'),
            planId: plan.id,
            planName: plan.name,
            memberId: member.id,
            memberName: member.fullName,
            sequenceNumber: sequence,
            periodLabel: PeriodLabel.monthYear(bounds.start),
            dueDate: bounds.dueDate,
            expectedAmount: plan.amount,
            paidAmount: 0,
            status: bounds.dueDate.isBefore(now)
                ? DuesStatus.late_
                : DuesStatus.pending,
          ),
        );
      }
    }
  }

  /// Recalcule la synthèse du plan à partir de ses échéances.
  DuesPlan _withSummary(DuesPlan plan) {
    double collected = 0;
    double outstanding = 0;
    int unpaid = 0;
    for (final DuesEntry entry in _db.duesEntries) {
      if (entry.planId != plan.id) {
        continue;
      }
      collected += entry.paidAmount;
      if (!entry.isSettled) {
        outstanding += entry.remainingAmount;
        unpaid++;
      }
    }
    return plan.copyWith(
      collectedTotal: collected,
      outstandingTotal: outstanding,
      unpaidCount: unpaid,
    );
  }

  /// Le journal ne doit jamais faire échouer l'opération métier qu'il trace.
  void _trace({
    required String organizationId,
    required AuditAction action,
    required String description,
    String? targetId,
    double? amount,
  }) {
    _audit
        .record(
          organizationId: organizationId,
          action: action,
          description: description,
          targetType: 'dues_plan',
          targetId: targetId,
          amount: amount,
        )
        .ignore();
  }
}
