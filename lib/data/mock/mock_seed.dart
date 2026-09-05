import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/core/utils/period_label.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/cash_transaction.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/notification_type.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/enums/transaction_enums.dart';
import 'package:kadjane/domain/services/period_calculator.dart';

/// Jeu de données de démonstration.
///
/// Il permet de parcourir toute l'application sans backend : deux
/// organisations, douze membres, des tontines dans les trois modes
/// d'attribution, des cycles passés soldés, un cycle en cours avec une
/// cotisation manquante (le tirage est donc bloqué tant qu'elle n'est pas
/// enregistrée), des tirages validés, des versements et un journal d'audit.
class MockSeed {
  const MockSeed._();

  /// Mot de passe accepté par le mock pour tous les comptes de démonstration.
  static const String demoPassword = 'kadjane';

  /// Code OTP accepté par le mock.
  static const String demoOtp = '123456';

  static const PeriodCalculator _periods = PeriodCalculator();

  static void populate(MockDatabase db) {
    final DateTime now = DateTime.now();
    final DateTime currentMonth = DateTime(now.year, now.month);

    // --- Utilisateurs -------------------------------------------------------
    final User yeo = _user(
      db,
      'Yedjane',
      'YEO',
      '+225 07 00 00 00 01',
      email: 'yeo@kadjane.app',
      gender: Gender.male,
    );
    final User awa = _user(
      db,
      'Awa',
      'KOUASSI',
      '+225 07 00 00 00 02',
      email: 'awa@kadjane.app',
      gender: Gender.female,
    );
    final User serge = _user(
      db,
      'Serge',
      'KOFFI',
      '+225 07 00 00 00 03',
      email: 'serge@kadjane.app',
      gender: Gender.male,
    );
    final User fatou = _user(
      db,
      'Fatou',
      'DIALLO',
      '+225 07 00 00 00 04',
      gender: Gender.female,
    );
    final User ibrahim = _user(
      db,
      'Ibrahim',
      'TRAORE',
      '+225 07 00 00 00 05',
      gender: Gender.male,
    );
    final User mariam = _user(
      db,
      'Mariam',
      'BAMBA',
      '+225 07 00 00 00 06',
      gender: Gender.female,
    );
    final User kouadio = _user(
      db,
      'Kouadio',
      'N GUESSAN',
      '+225 07 00 00 00 07',
      gender: Gender.male,
    );
    final User aminata = _user(
      db,
      'Aminata',
      'CISSE',
      '+225 07 00 00 00 08',
      gender: Gender.female,
    );
    final User jeanMarc = _user(
      db,
      'Jean-Marc',
      'ADJE',
      '+225 07 00 00 00 09',
      gender: Gender.male,
    );
    final User rokia = _user(
      db,
      'Rokia',
      'SANOGO',
      '+225 07 00 00 00 10',
      gender: Gender.female,
    );
    final User salif = _user(
      db,
      'Salif',
      'OUATTARA',
      '+225 07 00 00 00 11',
      gender: Gender.male,
    );
    final User celine = _user(
      db,
      'Celine',
      'GNAGNE',
      '+225 07 00 00 00 12',
      gender: Gender.female,
    );

    // --- Organisation principale -------------------------------------------
    final Organization solidarite = Organization(
      id: db.nextId('org'),
      name: 'Association Solidarité',
      description:
          'Association de solidarité familiale et professionnelle basée à '
          'Abidjan.',
      currency: Currency.xof,
      country: 'CI',
      phone: '+225 27 22 00 00 00',
      email: 'contact@solidarite.ci',
      address: 'Cocody Angré, Abidjan',
      rules:
          'Les cotisations sont dues le 5 de chaque mois. Le tirage a lieu '
          'une fois toutes les cotisations réglées.',
      createdAt: DateTime(currentMonth.year - 1, currentMonth.month),
    );
    db.organizations.add(solidarite);

    final OrganizationMember mYeo = _member(
      db,
      solidarite,
      yeo,
      OrgRole.admin,
      currentMonth,
      1,
    );
    final OrganizationMember mAwa = _member(
      db,
      solidarite,
      awa,
      OrgRole.treasurer,
      currentMonth,
      2,
    );
    final OrganizationMember mSerge = _member(
      db,
      solidarite,
      serge,
      OrgRole.president,
      currentMonth,
      3,
    );
    final OrganizationMember mFatou = _member(
      db,
      solidarite,
      fatou,
      OrgRole.auditor,
      currentMonth,
      4,
    );
    final OrganizationMember mIbrahim = _member(
      db,
      solidarite,
      ibrahim,
      OrgRole.member,
      currentMonth,
      5,
    );
    final OrganizationMember mMariam = _member(
      db,
      solidarite,
      mariam,
      OrgRole.member,
      currentMonth,
      6,
    );
    final OrganizationMember mKouadio = _member(
      db,
      solidarite,
      kouadio,
      OrgRole.member,
      currentMonth,
      7,
    );
    final OrganizationMember mAminata = _member(
      db,
      solidarite,
      aminata,
      OrgRole.member,
      currentMonth,
      8,
    );
    final OrganizationMember mJeanMarc = _member(
      db,
      solidarite,
      jeanMarc,
      OrgRole.member,
      currentMonth,
      9,
    );
    final OrganizationMember mRokia = _member(
      db,
      solidarite,
      rokia,
      OrgRole.member,
      currentMonth,
      10,
    );
    final OrganizationMember mSalif = _member(
      db,
      solidarite,
      salif,
      OrgRole.member,
      currentMonth,
      11,
    );
    final OrganizationMember mCeline = _member(
      db,
      solidarite,
      celine,
      OrgRole.member,
      currentMonth,
      12,
    );

    final List<OrganizationMember> allMembers = <OrganizationMember>[
      mYeo,
      mAwa,
      mSerge,
      mFatou,
      mIbrahim,
      mMariam,
      mKouadio,
      mAminata,
      mJeanMarc,
      mRokia,
      mSalif,
      mCeline,
    ];

    _seedMonthlyDrawTontine(
      db: db,
      organization: solidarite,
      members: allMembers,
      currentMonth: currentMonth,
      creator: mYeo,
      treasurer: mAwa,
      president: mSerge,
    );

    _seedFullOrderTontine(
      db: db,
      organization: solidarite,
      members: <OrganizationMember>[
        mAminata,
        mYeo,
        mIbrahim,
        mKouadio,
        mJeanMarc,
        mSalif,
      ],
      currentMonth: currentMonth,
      creator: mYeo,
      treasurer: mAwa,
    );

    // Tontine en brouillon : utile pour visualiser le statut correspondant.
    db.tontines.add(
      Tontine(
        id: db.nextId('ton'),
        organizationId: solidarite.id,
        name: 'Tontine Fêtes 2027',
        description: 'Tontine de fin d\'année, en cours de préparation.',
        contributionAmount: 75000,
        currency: Currency.xof,
        frequency: TontineFrequency.monthly,
        allocationMode: AllocationMode.monthlyDraw,
        startDate: DateTime(currentMonth.year, currentMonth.month + 4),
        status: TontineStatus.draft,
        createdAt: now.subtract(const Duration(days: 4)),
        createdBy: mYeo.id,
      ),
    );

    _seedTreasury(db, solidarite, currentMonth, mAwa);
    _seedDues(db, solidarite, currentMonth);

    // --- Seconde organisation (multi-organisation) -------------------------
    final Organization amicale = Organization(
      id: db.nextId('org'),
      name: 'Amicale des Anciens',
      description: 'Amicale des anciens élèves, promotion 2008.',
      currency: Currency.xof,
      country: 'CI',
      email: 'amicale2008@kadjane.app',
      createdAt: DateTime(currentMonth.year, currentMonth.month - 8),
      settings: const OrganizationSettings(
        requireFullPaymentBeforeDraw: false,
        allowDrawOverride: true,
        latePaymentGraceDays: 5,
      ),
    );
    db.organizations.add(amicale);

    final OrganizationMember aYeo = _member(
      db,
      amicale,
      yeo,
      OrgRole.treasurer,
      currentMonth,
      1,
    );
    final OrganizationMember aSerge = _member(
      db,
      amicale,
      serge,
      OrgRole.admin,
      currentMonth,
      2,
    );
    final OrganizationMember aKouadio = _member(
      db,
      amicale,
      kouadio,
      OrgRole.member,
      currentMonth,
      3,
    );
    final OrganizationMember aRokia = _member(
      db,
      amicale,
      rokia,
      OrgRole.member,
      currentMonth,
      4,
    );
    final OrganizationMember aCeline = _member(
      db,
      amicale,
      celine,
      OrgRole.president,
      currentMonth,
      5,
    );

    _seedManualOrderTontine(
      db: db,
      organization: amicale,
      members: <OrganizationMember>[aCeline, aYeo, aSerge, aKouadio, aRokia],
      currentMonth: currentMonth,
      creator: aSerge,
      treasurer: aYeo,
    );

    _seedNotifications(db, solidarite, yeo, currentMonth);
  }

  // --- Tontine principale : tirage à chaque période (mode A) ---------------

  static void _seedMonthlyDrawTontine({
    required MockDatabase db,
    required Organization organization,
    required List<OrganizationMember> members,
    required DateTime currentMonth,
    required OrganizationMember creator,
    required OrganizationMember treasurer,
    required OrganizationMember president,
  }) {
    const double amount = 50000;
    const int cycleCount = 12;
    final DateTime start = DateTime(currentMonth.year, currentMonth.month - 5);

    final Tontine tontine = Tontine(
      id: db.nextId('ton'),
      organizationId: organization.id,
      name: 'Tontine Solidarité',
      description:
          'Tontine mensuelle de l\'association. Un bénéficiaire est tiré au '
          'sort chaque mois parmi les membres n\'ayant pas encore reçu la '
          'cagnotte.',
      contributionAmount: amount,
      currency: organization.currency,
      frequency: TontineFrequency.monthly,
      allocationMode: AllocationMode.monthlyDraw,
      startDate: start,
      dueDayOfPeriod: 5,
      status: TontineStatus.active,
      createdAt: start.subtract(const Duration(days: 10)),
      createdBy: creator.id,
    );
    db.tontines.add(tontine);

    final List<TontineParticipant> participants = _addParticipants(
      db,
      tontine,
      members,
    );
    final List<TontineCycle> cycles = _addCycles(
      db,
      tontine,
      cycleCount,
      amount * participants.length,
    );

    _audit(
      db,
      organization.id,
      AuditAction.tontineCreated,
      '${creator.fullName} a créé la tontine « ${tontine.name} ».',
      actor: creator,
      tontineId: tontine.id,
      createdAt: tontine.createdAt,
    );

    // Cinq cycles passés entièrement soldés, avec tirage et versement.
    // À chaque période, le vainqueur précédent sort de la roue mais continue
    // de cotiser : la liste des éligibles se réduit de un à chaque cycle.
    final List<int> winners = <int>[1, 2, 3, 4, 5]; // Awa, Serge, Fatou...
    final Set<String> alreadyReceived = <String>{};
    for (int i = 0; i < 5; i++) {
      final TontineCycle cycle = cycles[i];
      final TontineParticipant winner = participants[winners[i]];

      _seedContributions(
        db: db,
        tontine: tontine,
        cycle: cycle,
        participants: participants,
        treasurer: treasurer,
        // Un paiement annulé puis re-saisi : il ne doit pas compter deux fois.
        cancelledMemberIds: i == 3
            ? <String>{participants[6].memberId}
            : const <String>{},
      );

      final DrawSession draw = _completeDraw(
        db: db,
        organization: organization,
        tontine: tontine,
        cycle: cycle,
        participants: participants,
        winner: winner,
        launchedBy: president,
        alreadyReceived: alreadyReceived,
      );
      alreadyReceived.add(winner.id);

      final Beneficiary beneficiary = Beneficiary(
        id: db.nextId('ben'),
        organizationId: organization.id,
        tontineId: tontine.id,
        cycleId: cycle.id,
        participantId: winner.id,
        memberId: winner.memberId,
        memberName: winner.displayName,
        amount: cycle.expectedAmount,
        designatedAt: draw.executedAt!,
        source: BeneficiarySource.periodicDraw,
        drawSessionId: draw.id,
      );
      db.beneficiaries.add(beneficiary);

      final Payout payout = Payout(
        id: db.nextId('pay'),
        organizationId: organization.id,
        tontineId: tontine.id,
        cycleId: cycle.id,
        beneficiaryId: beneficiary.id,
        memberId: winner.memberId,
        memberName: winner.displayName,
        amount: cycle.expectedAmount,
        status: PayoutStatus.paid,
        method: PaymentMethod.wave,
        reference: 'WV${cycle.index}${winner.memberId.hashCode.abs() % 10000}',
        sentAt: draw.executedAt!.add(const Duration(days: 1)),
        recordedBy: treasurer.id,
        createdAt: draw.executedAt!.add(const Duration(days: 1)),
      );
      db.payouts.add(payout);
      db.replaceBeneficiary(beneficiary.copyWith(payoutId: payout.id));

      db.replaceParticipant(
        winner.markAsBeneficiary(
          cycleId: cycle.id,
          periodStart: cycle.periodStart,
        ),
      );
      db.replaceCycle(
        cycle.copyWith(
          status: CycleStatus.closed,
          beneficiaryParticipantId: winner.id,
          beneficiaryId: beneficiary.id,
          drawSessionId: draw.id,
          payoutId: payout.id,
        ),
      );

      _audit(
        db,
        organization.id,
        AuditAction.payoutRecorded,
        '${treasurer.fullName} a confirmé le versement de '
        '${MoneyFormatter.format(payout.amount, tontine.currency)} à '
        '${winner.displayName}.',
        actor: treasurer,
        tontineId: tontine.id,
        amount: payout.amount,
        createdAt: payout.sentAt,
      );
    }

    // Cycle en cours : une cotisation manque, le tirage est donc bloqué.
    final TontineCycle current = cycles[5];
    _seedContributions(
      db: db,
      tontine: tontine,
      cycle: current,
      participants: participants,
      treasurer: treasurer,
      // Salif OUATTARA n'a pas encore payé : 11 / 12.
      skipMemberIds: <String>{participants[10].memberId},
    );
    db.replaceCycle(
      current.copyWith(
        status: CycleStatus.collecting,
        drawScheduledAt: current.dueDate.add(const Duration(days: 2)),
      ),
    );

    // Une première relance a déjà été envoyée au membre en retard.
    _seedReminder(
      db: db,
      organization: organization,
      tontine: tontine,
      cycle: current,
      participant: participants[10],
      sender: treasurer,
    );
  }

  // --- Tontine mode B : ordre complet défini par un tirage unique ----------

  static void _seedFullOrderTontine({
    required MockDatabase db,
    required Organization organization,
    required List<OrganizationMember> members,
    required DateTime currentMonth,
    required OrganizationMember creator,
    required OrganizationMember treasurer,
  }) {
    const double amount = 25000;
    final DateTime start = DateTime(currentMonth.year, currentMonth.month - 1);

    final Tontine tontine = Tontine(
      id: db.nextId('ton'),
      organizationId: organization.id,
      name: 'Tontine des Anciens',
      description:
          'L\'ordre de passage a été fixé par un tirage unique au démarrage.',
      contributionAmount: amount,
      currency: organization.currency,
      frequency: TontineFrequency.monthly,
      allocationMode: AllocationMode.fullOrderDraw,
      startDate: start,
      dueDayOfPeriod: 10,
      status: TontineStatus.active,
      createdAt: start.subtract(const Duration(days: 6)),
      createdBy: creator.id,
    );
    db.tontines.add(tontine);

    final List<TontineParticipant> participants = _addParticipants(
      db,
      tontine,
      members,
      withOrder: true,
    );
    final List<TontineCycle> cycles = _addCycles(
      db,
      tontine,
      members.length,
      amount * members.length,
    );

    // Tirage unique de l'ordre de passage.
    final DrawSession orderDraw = DrawSession(
      id: db.nextId('drw'),
      organizationId: organization.id,
      tontineId: tontine.id,
      cycleId: cycles.first.id,
      periodLabel: PeriodLabel.monthYear(cycles.first.periodStart),
      participants: participants.map(_toDrawParticipant).toList(),
      status: DrawStatus.completed,
      createdAt: tontine.createdAt,
      executedAt: tontine.createdAt,
      scheduledAt: tontine.createdAt,
      proofReference: 'KDJ-ORDER01',
      randomSourceLabel: 'client_secure_random',
      winnerParticipantId: participants.first.id,
      winnerMemberId: participants.first.memberId,
      winnerName: participants.first.displayName,
      launchedByMemberId: creator.id,
      launchedByName: creator.fullName,
    );
    db.draws.add(orderDraw);
    _audit(
      db,
      organization.id,
      AuditAction.orderGenerated,
      '${creator.fullName} a généré l\'ordre de passage de '
      '« ${tontine.name} ».',
      actor: creator,
      tontineId: tontine.id,
      createdAt: tontine.createdAt,
    );

    // Cycle 0 : soldé et versé.
    final TontineCycle first = cycles[0];
    _seedContributions(
      db: db,
      tontine: tontine,
      cycle: first,
      participants: participants,
      treasurer: treasurer,
    );
    final TontineParticipant firstWinner = participants.first;
    final Beneficiary beneficiary = Beneficiary(
      id: db.nextId('ben'),
      organizationId: organization.id,
      tontineId: tontine.id,
      cycleId: first.id,
      participantId: firstWinner.id,
      memberId: firstWinner.memberId,
      memberName: firstWinner.displayName,
      amount: first.expectedAmount,
      designatedAt: first.periodStart,
      source: BeneficiarySource.orderDraw,
      drawSessionId: orderDraw.id,
    );
    db.beneficiaries.add(beneficiary);
    final Payout payout = Payout(
      id: db.nextId('pay'),
      organizationId: organization.id,
      tontineId: tontine.id,
      cycleId: first.id,
      beneficiaryId: beneficiary.id,
      memberId: firstWinner.memberId,
      memberName: firstWinner.displayName,
      amount: first.expectedAmount,
      status: PayoutStatus.paid,
      method: PaymentMethod.orangeMoney,
      reference: 'OM77451',
      sentAt: first.dueDate.add(const Duration(days: 2)),
      recordedBy: treasurer.id,
      createdAt: first.dueDate.add(const Duration(days: 2)),
    );
    db.payouts.add(payout);
    db.replaceBeneficiary(beneficiary.copyWith(payoutId: payout.id));
    db.replaceParticipant(
      firstWinner.markAsBeneficiary(
        cycleId: first.id,
        periodStart: first.periodStart,
      ),
    );
    db.replaceCycle(
      first.copyWith(
        status: CycleStatus.closed,
        beneficiaryParticipantId: firstWinner.id,
        beneficiaryId: beneficiary.id,
        payoutId: payout.id,
        drawSessionId: orderDraw.id,
      ),
    );

    // Cycle courant : bénéficiaire connu d'avance, versement encore en attente.
    final TontineCycle current = cycles[1];
    _seedContributions(
      db: db,
      tontine: tontine,
      cycle: current,
      participants: participants,
      treasurer: treasurer,
      skipMemberIds: <String>{participants[4].memberId},
    );
    final TontineParticipant nextWinner = participants[1];
    final Beneficiary currentBeneficiary = Beneficiary(
      id: db.nextId('ben'),
      organizationId: organization.id,
      tontineId: tontine.id,
      cycleId: current.id,
      participantId: nextWinner.id,
      memberId: nextWinner.memberId,
      memberName: nextWinner.displayName,
      amount: current.expectedAmount,
      designatedAt: current.periodStart,
      source: BeneficiarySource.orderDraw,
      drawSessionId: orderDraw.id,
    );
    db.beneficiaries.add(currentBeneficiary);
    db.replaceParticipant(
      nextWinner.markAsBeneficiary(
        cycleId: current.id,
        periodStart: current.periodStart,
      ),
    );
    db.replaceCycle(
      current.copyWith(
        status: CycleStatus.drawn,
        beneficiaryParticipantId: nextWinner.id,
        beneficiaryId: currentBeneficiary.id,
        drawSessionId: orderDraw.id,
      ),
    );
    _audit(
      db,
      organization.id,
      AuditAction.beneficiaryDesignated,
      '${nextWinner.displayName} est le bénéficiaire de '
      '${PeriodLabel.monthYear(current.periodStart)} '
      '(ordre de passage).',
      actor: creator,
      tontineId: tontine.id,
      amount: current.expectedAmount,
      createdAt: current.periodStart,
    );
  }

  // --- Tontine mode C : ordre manuel (seconde organisation) ---------------

  static void _seedManualOrderTontine({
    required MockDatabase db,
    required Organization organization,
    required List<OrganizationMember> members,
    required DateTime currentMonth,
    required OrganizationMember creator,
    required OrganizationMember treasurer,
  }) {
    const double amount = 10000;
    final DateTime start = DateTime(currentMonth.year, currentMonth.month - 2);

    final Tontine tontine = Tontine(
      id: db.nextId('ton'),
      organizationId: organization.id,
      name: 'Tontine Amicale',
      description: 'Ordre de passage défini manuellement par le bureau.',
      contributionAmount: amount,
      currency: organization.currency,
      frequency: TontineFrequency.monthly,
      allocationMode: AllocationMode.manualOrder,
      startDate: start,
      dueDayOfPeriod: 8,
      status: TontineStatus.active,
      createdAt: start.subtract(const Duration(days: 3)),
      createdBy: creator.id,
    );
    db.tontines.add(tontine);

    final List<TontineParticipant> participants = _addParticipants(
      db,
      tontine,
      members,
      withOrder: true,
    );
    final List<TontineCycle> cycles = _addCycles(
      db,
      tontine,
      members.length,
      amount * members.length,
    );

    for (int i = 0; i < 2; i++) {
      final TontineCycle cycle = cycles[i];
      final TontineParticipant winner = participants[i];
      _seedContributions(
        db: db,
        tontine: tontine,
        cycle: cycle,
        participants: participants,
        treasurer: treasurer,
      );
      final Beneficiary beneficiary = Beneficiary(
        id: db.nextId('ben'),
        organizationId: organization.id,
        tontineId: tontine.id,
        cycleId: cycle.id,
        participantId: winner.id,
        memberId: winner.memberId,
        memberName: winner.displayName,
        amount: cycle.expectedAmount,
        designatedAt: cycle.periodStart,
        source: BeneficiarySource.manualOrder,
      );
      db.beneficiaries.add(beneficiary);
      final Payout payout = Payout(
        id: db.nextId('pay'),
        organizationId: organization.id,
        tontineId: tontine.id,
        cycleId: cycle.id,
        beneficiaryId: beneficiary.id,
        memberId: winner.memberId,
        memberName: winner.displayName,
        amount: cycle.expectedAmount,
        status: PayoutStatus.paid,
        method: PaymentMethod.cash,
        sentAt: cycle.dueDate.add(const Duration(days: 1)),
        recordedBy: treasurer.id,
        createdAt: cycle.dueDate.add(const Duration(days: 1)),
      );
      db.payouts.add(payout);
      db.replaceBeneficiary(beneficiary.copyWith(payoutId: payout.id));
      db.replaceParticipant(
        winner.markAsBeneficiary(
          cycleId: cycle.id,
          periodStart: cycle.periodStart,
        ),
      );
      db.replaceCycle(
        cycle.copyWith(
          status: CycleStatus.closed,
          beneficiaryParticipantId: winner.id,
          beneficiaryId: beneficiary.id,
          payoutId: payout.id,
        ),
      );
    }

    final TontineCycle current = cycles[2];
    _seedContributions(
      db: db,
      tontine: tontine,
      cycle: current,
      participants: participants,
      treasurer: treasurer,
      skipMemberIds: <String>{
        participants[3].memberId,
        participants[4].memberId,
      },
    );
    db.replaceCycle(current.copyWith(status: CycleStatus.collecting));
  }

  // --- Helpers -------------------------------------------------------------

  /// Relance déjà envoyée, avec sa campagne, pour alimenter l'historique.
  static void _seedReminder({
    required MockDatabase db,
    required Organization organization,
    required Tontine tontine,
    required TontineCycle cycle,
    required TontineParticipant participant,
    required OrganizationMember sender,
  }) {
    final DateTime sentAt = DateTime.now().subtract(const Duration(days: 3));
    final String periodLabel = PeriodLabel.monthYear(cycle.periodStart);
    final String message =
        'Bonjour ${participant.displayName}, votre cotisation de '
        '${MoneyFormatter.format(tontine.contributionAmount, tontine.currency)} '
        'pour ${tontine.name} ($periodLabel) est en retard. '
        'Le tirage restera bloqué tant que la cotisation ne sera pas '
        'réglée.';

    final String campaignId = db.nextId('cmp');
    db.reminders.add(
      Reminder(
        id: db.nextId('rmd'),
        organizationId: organization.id,
        tontineId: tontine.id,
        cycleId: cycle.id,
        memberId: participant.memberId,
        memberName: participant.displayName,
        channel: ReminderChannel.inApp,
        status: ReminderStatus.sent,
        level: ReminderLevel.late_,
        message: message,
        amountDue: tontine.contributionAmount,
        dueDate: cycle.dueDate,
        createdAt: sentAt,
        campaignId: campaignId,
        sentAt: sentAt,
        sentByMemberId: sender.id,
        sentByName: sender.fullName,
      ),
    );
    db.campaigns.add(
      ReminderCampaign(
        id: campaignId,
        organizationId: organization.id,
        tontineId: tontine.id,
        tontineName: tontine.name,
        cycleId: cycle.id,
        periodLabel: periodLabel,
        channels: const <ReminderChannel>[ReminderChannel.inApp],
        targetCount: 1,
        sentCount: 1,
        totalAmountDue: tontine.contributionAmount,
        createdAt: sentAt,
        createdByMemberId: sender.id,
        createdByName: sender.fullName,
      ),
    );
    _audit(
      db,
      organization.id,
      AuditAction.reminderSent,
      '1 relance envoyée à ${participant.displayName} pour $periodLabel.',
      actor: sender,
      tontineId: tontine.id,
      amount: tontine.contributionAmount,
      createdAt: sentAt,
    );
  }

  static User _user(
    MockDatabase db,
    String firstName,
    String lastName,
    String phone, {
    String? email,
    Gender gender = Gender.unspecified,
  }) {
    final User user = User(
      id: db.nextId('usr'),
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      gender: gender,
      createdAt: DateTime(2025, 1, 1),
    );
    db.users.add(user);
    db.passwords[user.id] = demoPassword;
    return user;
  }

  static OrganizationMember _member(
    MockDatabase db,
    Organization organization,
    User user,
    OrgRole role,
    DateTime reference,
    int number,
  ) {
    final OrganizationMember member = OrganizationMember(
      id: db.nextId('mbr'),
      organizationId: organization.id,
      user: user,
      role: role,
      joinedAt: DateTime(reference.year - 1, reference.month, 15),
      memberNumber: 'M-${number.toString().padLeft(3, '0')}',
    );
    db.members.add(member);
    return member;
  }

  static List<TontineParticipant> _addParticipants(
    MockDatabase db,
    Tontine tontine,
    List<OrganizationMember> members, {
    bool withOrder = false,
  }) {
    final List<TontineParticipant> result = <TontineParticipant>[];
    for (int i = 0; i < members.length; i++) {
      final OrganizationMember member = members[i];
      final TontineParticipant participant = TontineParticipant(
        id: db.nextId('prt'),
        tontineId: tontine.id,
        memberId: member.id,
        displayName: member.fullName,
        joinedAt: tontine.startDate,
        orderPosition: withOrder ? i + 1 : null,
      );
      db.participants.add(participant);
      result.add(participant);
    }
    return result;
  }

  static List<TontineCycle> _addCycles(
    MockDatabase db,
    Tontine tontine,
    int count,
    double expectedAmount,
  ) {
    final List<PeriodBounds> bounds = _periods.generate(
      startDate: tontine.startDate,
      frequency: tontine.frequency,
      count: count,
      dueDayOfPeriod: tontine.dueDayOfPeriod,
      customPeriodDays: tontine.customPeriodDays,
    );
    final List<TontineCycle> result = <TontineCycle>[];
    for (int i = 0; i < bounds.length; i++) {
      final TontineCycle cycle = TontineCycle(
        id: db.nextId('cyc'),
        tontineId: tontine.id,
        index: i + 1,
        periodStart: bounds[i].start,
        periodEnd: bounds[i].end,
        dueDate: bounds[i].dueDate,
        expectedAmount: expectedAmount,
        status: CycleStatus.upcoming,
      );
      db.cycles.add(cycle);
      result.add(cycle);
    }
    return result;
  }

  static const List<PaymentMethod> _methods = <PaymentMethod>[
    PaymentMethod.wave,
    PaymentMethod.orangeMoney,
    PaymentMethod.mtnMomo,
    PaymentMethod.cash,
    PaymentMethod.moovMoney,
    PaymentMethod.bankTransfer,
  ];

  static void _seedContributions({
    required MockDatabase db,
    required Tontine tontine,
    required TontineCycle cycle,
    required List<TontineParticipant> participants,
    required OrganizationMember treasurer,
    Set<String> skipMemberIds = const <String>{},
    Set<String> cancelledMemberIds = const <String>{},
  }) {
    for (int i = 0; i < participants.length; i++) {
      final TontineParticipant participant = participants[i];
      if (skipMemberIds.contains(participant.memberId)) {
        continue;
      }
      final DateTime paidAt = cycle.periodStart.add(Duration(days: 1 + i % 5));
      final PaymentMethod method = _methods[i % _methods.length];

      if (cancelledMemberIds.contains(participant.memberId)) {
        // Paiement annulé : conservé dans l'historique, exclu du collecté.
        db.contributions.add(
          Contribution(
            id: db.nextId('ctr'),
            organizationId: tontine.organizationId,
            tontineId: tontine.id,
            cycleId: cycle.id,
            memberId: participant.memberId,
            memberName: participant.displayName,
            amount: tontine.contributionAmount,
            status: ContributionStatus.cancelled,
            recordedAt: paidAt,
            paidAt: paidAt,
            method: method,
            recordedBy: treasurer.id,
            cancelledAt: paidAt.add(const Duration(days: 1)),
            cancelReason: 'Référence de transfert erronée',
          ),
        );
      }

      db.contributions.add(
        Contribution(
          id: db.nextId('ctr'),
          organizationId: tontine.organizationId,
          tontineId: tontine.id,
          cycleId: cycle.id,
          memberId: participant.memberId,
          memberName: participant.displayName,
          amount: tontine.contributionAmount,
          status: ContributionStatus.confirmed,
          recordedAt: paidAt,
          paidAt: paidAt,
          method: method,
          reference: method == PaymentMethod.cash
              ? null
              : 'REF${cycle.index}${(i + 1).toString().padLeft(2, '0')}',
          recordedBy: treasurer.id,
        ),
      );
    }
  }

  static DrawSession _completeDraw({
    required MockDatabase db,
    required Organization organization,
    required Tontine tontine,
    required TontineCycle cycle,
    required List<TontineParticipant> participants,
    required TontineParticipant winner,
    required OrganizationMember launchedBy,
    Set<String> alreadyReceived = const <String>{},
  }) {
    final List<DrawParticipant> eligible = participants
        .where((TontineParticipant p) => !alreadyReceived.contains(p.id))
        .map(_toDrawParticipant)
        .toList();
    final DateTime executedAt = cycle.dueDate.add(const Duration(hours: 14));
    final DrawSession draw = DrawSession(
      id: db.nextId('drw'),
      organizationId: organization.id,
      tontineId: tontine.id,
      cycleId: cycle.id,
      periodLabel: PeriodLabel.monthYear(cycle.periodStart),
      participants: eligible,
      status: DrawStatus.completed,
      createdAt: cycle.dueDate,
      scheduledAt: cycle.dueDate,
      executedAt: executedAt,
      winnerParticipantId: winner.id,
      winnerMemberId: winner.memberId,
      winnerName: winner.displayName,
      launchedByMemberId: launchedBy.id,
      launchedByName: launchedBy.fullName,
      proofReference:
          'KDJ-${cycle.index.toString().padLeft(2, '0')}'
          '${winner.id.substring(winner.id.length - 3)}',
      randomSourceLabel: 'client_secure_random',
    );
    db.draws.add(draw);
    _audit(
      db,
      organization.id,
      AuditAction.drawCompleted,
      '${winner.displayName} a été tiré(e) comme bénéficiaire de '
      '${PeriodLabel.monthYear(cycle.periodStart)}.',
      actor: launchedBy,
      tontineId: tontine.id,
      amount: cycle.expectedAmount,
      createdAt: executedAt,
    );
    return draw;
  }

  static DrawParticipant _toDrawParticipant(TontineParticipant p) =>
      DrawParticipant(
        participantId: p.id,
        memberId: p.memberId,
        displayName: p.displayName,
      );

  static void _seedTreasury(
    MockDatabase db,
    Organization organization,
    DateTime currentMonth,
    OrganizationMember treasurer,
  ) {
    final List<CashTransaction> entries = <CashTransaction>[
      CashTransaction(
        id: db.nextId('trx'),
        organizationId: organization.id,
        type: TransactionType.income,
        category: TransactionCategory.donation,
        amount: 150000,
        date: DateTime(currentMonth.year, currentMonth.month - 2, 12),
        description: 'Don du parrain de l\'association',
        createdBy: treasurer.id,
        createdAt: DateTime(currentMonth.year, currentMonth.month - 2, 12),
      ),
      CashTransaction(
        id: db.nextId('trx'),
        organizationId: organization.id,
        type: TransactionType.income,
        category: TransactionCategory.fee,
        amount: 60000,
        date: DateTime(currentMonth.year, currentMonth.month - 1, 3),
        description: 'Droits d\'adhésion 2026',
        createdBy: treasurer.id,
        createdAt: DateTime(currentMonth.year, currentMonth.month - 1, 3),
      ),
      CashTransaction(
        id: db.nextId('trx'),
        organizationId: organization.id,
        type: TransactionType.expense,
        category: TransactionCategory.socialAid,
        amount: 75000,
        date: DateTime(currentMonth.year, currentMonth.month - 1, 21),
        description: 'Aide sociale — soutien à un membre',
        createdBy: treasurer.id,
        createdAt: DateTime(currentMonth.year, currentMonth.month - 1, 21),
      ),
      CashTransaction(
        id: db.nextId('trx'),
        organizationId: organization.id,
        type: TransactionType.expense,
        category: TransactionCategory.event,
        amount: 42000,
        date: DateTime(currentMonth.year, currentMonth.month, 4),
        description: 'Location de salle pour l\'assemblée générale',
        createdBy: treasurer.id,
        createdAt: DateTime(currentMonth.year, currentMonth.month, 4),
      ),
    ];
    db.transactions.addAll(entries);
  }

  static void _seedNotifications(
    MockDatabase db,
    Organization organization,
    User user,
    DateTime currentMonth,
  ) {
    final DateTime now = DateTime.now();
    db.notifications.addAll(<AppNotification>[
      AppNotification(
        id: db.nextId('ntf'),
        userId: user.id,
        organizationId: organization.id,
        type: NotificationType.contributionDue,
        title: 'Cotisation à venir',
        body:
            'Votre cotisation de 50 000 FCFA pour '
            '${PeriodLabel.monthYear(currentMonth)} est attendue.',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: db.nextId('ntf'),
        userId: user.id,
        organizationId: organization.id,
        type: NotificationType.contributionLate,
        title: 'Cotisation en retard',
        body: '1 membre n\'a pas encore réglé sa cotisation du mois.',
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
      AppNotification(
        id: db.nextId('ntf'),
        userId: user.id,
        organizationId: organization.id,
        type: NotificationType.drawScheduled,
        title: 'Tirage programmé',
        body:
            'Le tirage de ${PeriodLabel.monthYear(currentMonth)} aura lieu '
            'dès que toutes les cotisations seront réglées.',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      AppNotification(
        id: db.nextId('ntf'),
        userId: user.id,
        organizationId: organization.id,
        type: NotificationType.payoutDone,
        title: 'Versement effectué',
        body: 'La cagnotte du mois précédent a été versée au bénéficiaire.',
        createdAt: now.subtract(const Duration(days: 6)),
        readAt: now.subtract(const Duration(days: 5)),
      ),
      AppNotification(
        id: db.nextId('ntf'),
        userId: user.id,
        organizationId: organization.id,
        type: NotificationType.announcement,
        title: 'Assemblée générale',
        body: 'L\'assemblée générale se tiendra le 30 du mois à 15h00.',
        createdAt: now.subtract(const Duration(days: 9)),
        readAt: now.subtract(const Duration(days: 8)),
      ),
    ]);
  }

  /// Cotisations de caisse de démonstration.
  ///
  /// Seuls les plans sont posés : les échéances sont engendrées à la lecture
  /// par le repository, exactement comme le fait le backend.
  static void _seedDues(
    MockDatabase db,
    Organization organization,
    DateTime currentMonth,
  ) {
    db.duesPlans.addAll(<DuesPlan>[
      DuesPlan(
        id: db.nextId('dpl'),
        organizationId: organization.id,
        name: 'Caisse de solidarité',
        description: 'Fonds d\'entraide en cas de coup dur.',
        amount: 5000,
        frequency: TontineFrequency.monthly,
        dueDay: 5,
        startDate: DateTime(currentMonth.year, currentMonth.month - 2),
        status: DuesPlanStatus.active,
      ),
      DuesPlan(
        id: db.nextId('dpl'),
        organizationId: organization.id,
        name: 'Fonds événement',
        description: 'Cotisation ouverte pour l\'assemblée générale.',
        amount: 2000,
        frequency: TontineFrequency.monthly,
        dueDay: 15,
        startDate: DateTime(currentMonth.year, currentMonth.month - 1),
        status: DuesPlanStatus.paused,
      ),
    ]);
  }

  static void _audit(
    MockDatabase db,
    String organizationId,
    AuditAction action,
    String description, {
    OrganizationMember? actor,
    String? tontineId,
    double? amount,
    DateTime? createdAt,
  }) {
    db.auditLogs.add(
      AuditLog(
        id: db.nextId('adt'),
        organizationId: organizationId,
        action: action,
        description: description,
        actorMemberId: actor?.id,
        actorName: actor?.fullName ?? 'Système',
        tontineId: tontineId,
        amount: amount,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }
}
