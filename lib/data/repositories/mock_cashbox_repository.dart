import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';
import 'package:kadjane/domain/repositories/cashbox_repository.dart';

/// Caisses et cotisations en mémoire, pour la démonstration hors ligne.
///
/// Le solde y est recomposé exactement comme le fait le serveur — solde
/// d'ouverture, plus les entrées, moins les sorties — pour que le mode
/// démonstration ne raconte pas une autre arithmétique que la production.
class MockCashboxRepository implements CashboxRepository {
  MockCashboxRepository(this._db);

  final MockDatabase _db;

  final List<Cashbox> _cashboxes = <Cashbox>[];
  final List<ContributionCampaign> _campaigns = <ContributionCampaign>[];
  final Map<String, List<CampaignEntry>> _entries =
      <String, List<CampaignEntry>>{};

  int _sequence = 0;

  String _nextId(String prefix) => '${prefix}_mock_${++_sequence}';

  @override
  Future<List<Cashbox>> cashboxes(String organizationId) =>
      _db.withLatency(() {
        _ensureDefault(organizationId);
        return List<Cashbox>.unmodifiable(
          _cashboxes.where(
            (Cashbox box) => box.organizationId == organizationId,
          ),
        );
      });

  @override
  Future<Cashbox> createCashbox({
    required String organizationId,
    required String name,
    String? description,
    double openingBalance = 0,
    bool isDefault = false,
  }) => _db.withLatency(() {
    final Cashbox cashbox = Cashbox(
      id: _nextId('box'),
      organizationId: organizationId,
      name: name,
      description: description,
      currency: 'XOF',
      openingBalance: openingBalance,
      currentBalance: openingBalance,
      inflows: 0,
      outflows: 0,
      status: CashboxStatus.open,
      isDefault: isDefault || _cashboxes.isEmpty,
      createdAt: DateTime.now(),
    );
    _cashboxes.add(cashbox);
    return cashbox;
  });

  @override
  Future<void> recordMovement({
    required String cashboxId,
    required String type,
    required String category,
    required double amount,
    String? description,
    String? reference,
  }) => _db.withLatency(() {
    final int index = _cashboxes.indexWhere((Cashbox b) => b.id == cashboxId);
    if (index == -1) {
      return;
    }
    final Cashbox box = _cashboxes[index];
    final bool incoming = type == 'income';
    _cashboxes[index] = _rebalanced(
      box,
      inflows: box.inflows + (incoming ? amount : 0),
      outflows: box.outflows + (incoming ? 0 : amount),
    );
  });

  @override
  Future<FinancialDashboard> financialDashboard(String organizationId) =>
      _db.withLatency(() {
        _ensureDefault(organizationId);
        final List<Cashbox> boxes = _cashboxes
            .where((Cashbox b) => b.organizationId == organizationId)
            .toList(growable: false);
        final List<CampaignEntry> lines = _allEntries(organizationId);

        final double expected = lines
            .where((CampaignEntry e) => e.status.isOwed)
            .fold(0, (double sum, CampaignEntry e) => sum + e.expectedAmount);
        final double collected = lines.fold(
          0,
          (double sum, CampaignEntry e) => sum + e.paidAmount,
        );

        return FinancialDashboard(
          cashBalance: boxes.fold(
            0,
            (double sum, Cashbox b) => sum + b.currentBalance,
          ),
          cashboxes: boxes,
          monthInflows: boxes.fold(0, (double s, Cashbox b) => s + b.inflows),
          monthOutflows: boxes.fold(0, (double s, Cashbox b) => s + b.outflows),
          expected: expected,
          collected: collected,
          remaining: (expected - collected).clamp(0, double.infinity),
          lateAmount: lines
              .where((CampaignEntry e) => e.status == CampaignEntryStatus.late_)
              .fold(0, (double s, CampaignEntry e) => s + e.remainingAmount),
          recoveryRate: expected > 0 ? (collected / expected) * 100 : null,
        );
      });

  @override
  Future<List<ContributionCampaign>> campaigns(
    String organizationId, {
    String? status,
    String? type,
  }) => _db.withLatency(
    () => List<ContributionCampaign>.unmodifiable(
      _campaigns.where(
        (ContributionCampaign c) =>
            c.organizationId == organizationId &&
            (status == null || c.status.code == status) &&
            (type == null || c.contributionType.code == type),
      ),
    ),
  );

  @override
  Future<ContributionCampaign> campaign(String campaignId) =>
      _db.withLatency(() => _withEntries(_find(campaignId)));

  @override
  Future<ContributionCampaign> createCampaign({
    required String organizationId,
    required String title,
    required ContributionType contributionType,
    required double amount,
    AmountMode amountMode = AmountMode.fixed,
    String? description,
    DateTime? dueDate,
    List<String>? memberIds,
    String? cashboxId,
    bool mandatory = true,
    bool penaltyEnabled = false,
    double penaltyAmount = 0,
  }) => _db.withLatency(() {
    final String id = _nextId('cmp');
    final List<String> targets =
        memberIds ??
        _db.members
            .where((dynamic m) => m.organizationId == organizationId)
            .map<String>((dynamic m) => m.id as String)
            .toList(growable: false);

    _entries[id] = <CampaignEntry>[
      for (final String memberId in targets)
        CampaignEntry(
          id: _nextId('ent'),
          organizationId: organizationId,
          campaignId: id,
          memberId: memberId,
          memberName: memberId,
          expectedAmount: amountMode == AmountMode.fixed ? amount : 0,
          paidAmount: 0,
          remainingAmount: amountMode == AmountMode.fixed ? amount : 0,
          dueDate: dueDate,
          status: CampaignEntryStatus.pending,
          daysLate: 0,
        ),
    ];

    final ContributionCampaign campaign = ContributionCampaign(
      id: id,
      organizationId: organizationId,
      title: title,
      description: description,
      contributionType: contributionType,
      amount: amount,
      amountMode: amountMode,
      currency: 'XOF',
      status: CampaignStatus.active,
      mandatory: mandatory,
      penaltyEnabled: penaltyEnabled,
      penaltyAmount: penaltyAmount,
      dueDate: dueDate,
      cashboxId: cashboxId,
      createdAt: DateTime.now(),
    );
    _campaigns.add(campaign);
    return _withEntries(campaign);
  });

  @override
  Future<CampaignEntry> recordPayment({
    required String entryId,
    required double amount,
    required String paymentMethod,
    String? reference,
    String? comment,
  }) => _db.withLatency(() {
    final CampaignEntry entry = _entry(entryId);
    final double paid = entry.paidAmount + amount;
    final double remaining = (entry.expectedAmount - paid).clamp(
      0,
      double.infinity,
    );
    final CampaignEntry updated = CampaignEntry(
      id: entry.id,
      organizationId: entry.organizationId,
      campaignId: entry.campaignId,
      memberId: entry.memberId,
      memberName: entry.memberName,
      expectedAmount: entry.expectedAmount,
      paidAmount: paid,
      remainingAmount: remaining,
      dueDate: entry.dueDate,
      status: remaining <= 0
          ? CampaignEntryStatus.paid
          : CampaignEntryStatus.partial,
      lastPaymentAt: DateTime.now(),
      daysLate: entry.daysLate,
      campaignTitle: entry.campaignTitle,
    );
    _replace(updated);

    // Le règlement alimente la caisse : une saisie, deux effets, comme côté
    // serveur — jamais une écriture manuelle en plus.
    final ContributionCampaign campaign = _find(entry.campaignId);
    if (campaign.contributionType.feedsCashbox) {
      final int index = _cashboxes.indexWhere(
        (Cashbox b) =>
            b.id == (campaign.cashboxId ?? _defaultBoxId(entry.organizationId)),
      );
      if (index != -1) {
        _cashboxes[index] = _rebalanced(
          _cashboxes[index],
          inflows: _cashboxes[index].inflows + amount,
          outflows: _cashboxes[index].outflows,
        );
      }
    }
    return updated;
  });

  @override
  Future<CampaignEntry> exempt({required String entryId, String? reason}) =>
      _db.withLatency(() {
        final CampaignEntry entry = _entry(entryId);
        final CampaignEntry updated = CampaignEntry(
          id: entry.id,
          organizationId: entry.organizationId,
          campaignId: entry.campaignId,
          memberId: entry.memberId,
          memberName: entry.memberName,
          expectedAmount: entry.expectedAmount,
          paidAmount: entry.paidAmount,
          remainingAmount: entry.remainingAmount,
          dueDate: entry.dueDate,
          status: CampaignEntryStatus.exempted,
          exemptionReason: reason,
          daysLate: 0,
          campaignTitle: entry.campaignTitle,
        );
        _replace(updated);
        return updated;
      });

  @override
  Future<List<CampaignEntry>> unpaid(String organizationId) => _db.withLatency(
    () => List<CampaignEntry>.unmodifiable(
      _allEntries(organizationId).where(
        (CampaignEntry e) => e.status.isOwed && e.remainingAmount > 0,
      ),
    ),
  );

  // --- Interne ---------------------------------------------------------------

  void _ensureDefault(String organizationId) {
    final bool exists = _cashboxes.any(
      (Cashbox b) => b.organizationId == organizationId,
    );
    if (exists) {
      return;
    }
    _cashboxes.add(
      Cashbox(
        id: _nextId('box'),
        organizationId: organizationId,
        name: 'Caisse principale',
        currency: 'XOF',
        openingBalance: 0,
        currentBalance: 0,
        inflows: 0,
        outflows: 0,
        status: CashboxStatus.open,
        isDefault: true,
        createdAt: DateTime.now(),
      ),
    );
  }

  String? _defaultBoxId(String organizationId) {
    for (final Cashbox box in _cashboxes) {
      if (box.organizationId == organizationId && box.isDefault) {
        return box.id;
      }
    }
    return null;
  }

  /// Recompose le solde plutôt que de l'incrémenter : même règle qu'en base.
  Cashbox _rebalanced(
    Cashbox box, {
    required double inflows,
    required double outflows,
  }) => Cashbox(
    id: box.id,
    organizationId: box.organizationId,
    name: box.name,
    description: box.description,
    currency: box.currency,
    openingBalance: box.openingBalance,
    currentBalance: box.openingBalance + inflows - outflows,
    inflows: inflows,
    outflows: outflows,
    status: box.status,
    isDefault: box.isDefault,
    createdAt: box.createdAt,
    closedAt: box.closedAt,
  );

  ContributionCampaign _find(String campaignId) =>
      _campaigns.firstWhere((ContributionCampaign c) => c.id == campaignId);

  CampaignEntry _entry(String entryId) {
    for (final List<CampaignEntry> lines in _entries.values) {
      for (final CampaignEntry entry in lines) {
        if (entry.id == entryId) {
          return entry;
        }
      }
    }
    throw StateError('Ligne de cotisation introuvable : $entryId');
  }

  void _replace(CampaignEntry updated) {
    final List<CampaignEntry>? lines = _entries[updated.campaignId];
    if (lines == null) {
      return;
    }
    final int index = lines.indexWhere((CampaignEntry e) => e.id == updated.id);
    if (index != -1) {
      lines[index] = updated;
    }
  }

  List<CampaignEntry> _allEntries(String organizationId) => <CampaignEntry>[
    for (final List<CampaignEntry> lines in _entries.values)
      ...lines.where(
        (CampaignEntry e) => e.organizationId == organizationId,
      ),
  ];

  ContributionCampaign _withEntries(ContributionCampaign campaign) {
    final List<CampaignEntry> lines =
        _entries[campaign.id] ?? const <CampaignEntry>[];
    final List<CampaignEntry> owed = lines
        .where((CampaignEntry e) => e.status.isOwed)
        .toList(growable: false);
    final double expected = owed.fold(
      0,
      (double sum, CampaignEntry e) => sum + e.expectedAmount,
    );
    final double collected = lines.fold(
      0,
      (double sum, CampaignEntry e) => sum + e.paidAmount,
    );

    return ContributionCampaign(
      id: campaign.id,
      organizationId: campaign.organizationId,
      tontineId: campaign.tontineId,
      cashboxId: campaign.cashboxId,
      title: campaign.title,
      description: campaign.description,
      contributionType: campaign.contributionType,
      amount: campaign.amount,
      amountMode: campaign.amountMode,
      currency: campaign.currency,
      startDate: campaign.startDate,
      dueDate: campaign.dueDate,
      mandatory: campaign.mandatory,
      penaltyEnabled: campaign.penaltyEnabled,
      penaltyAmount: campaign.penaltyAmount,
      status: campaign.status,
      createdAt: campaign.createdAt,
      entries: lines,
      summary: CampaignSummary(
        membersCount: lines.length,
        expected: expected,
        collected: collected,
        remaining: (expected - collected).clamp(0, double.infinity),
        recoveryRate: expected > 0 ? (collected / expected) * 100 : null,
        paidCount: _count(lines, CampaignEntryStatus.paid),
        partialCount: _count(lines, CampaignEntryStatus.partial),
        pendingCount: _count(lines, CampaignEntryStatus.pending),
        lateCount: _count(lines, CampaignEntryStatus.late_),
        exemptedCount: _count(lines, CampaignEntryStatus.exempted),
      ),
    );
  }

  static int _count(List<CampaignEntry> lines, CampaignEntryStatus status) =>
      lines.where((CampaignEntry e) => e.status == status).length;
}
