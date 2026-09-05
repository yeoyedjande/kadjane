import { CommonModule } from '@angular/common';
import { Component, computed, inject, input, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { forkJoin, of } from 'rxjs';

import {
  Beneficiary,
  ContributionLine,
  ContributionTotals,
  DrawEligibility,
  DrawSession,
  PaymentMethod,
  Payout,
  Tontine,
  TontineCycle,
  TontineParticipant,
  TontineSummary,
} from '../../core/models/domain.models';
import {
  AmountPipe,
  FrDatePipe,
  LabelPipe,
  MoneyPipe,
} from '../../core/pipes/format.pipes';
import {
  AuditService,
  BeneficiaryService,
  ContributionService,
  DrawService,
  PaymentService,
  PayoutService,
  TontineService,
} from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  ConfirmDialog,
  ConfirmRequest,
  PageHeader,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

type Tab =
  | 'overview'
  | 'participants'
  | 'cycles'
  | 'contributions'
  | 'draws'
  | 'beneficiaries'
  | 'history'
  | 'settings';

export const PAYMENT_METHODS: PaymentMethod[] = [
  'cash',
  'wave',
  'orange_money',
  'mtn_momo',
  'moov_money',
  'bank_transfer',
  'other',
];

@Component({
  selector: 'app-tontine-detail',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    RouterLink,
    AmountPipe,
    FrDatePipe,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
    ConfirmDialog,
  ],
  templateUrl: './tontine-detail.component.html',
})
export class TontineDetailPage {
  private readonly tontines = inject(TontineService);
  private readonly contributions = inject(ContributionService);
  private readonly payments = inject(PaymentService);
  private readonly draws = inject(DrawService);
  private readonly beneficiaries = inject(BeneficiaryService);
  private readonly payouts = inject(PayoutService);
  private readonly audit = inject(AuditService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly id = input.required<string>();
  readonly methods = PAYMENT_METHODS;

  readonly summary = signal<TontineSummary | null>(null);
  readonly participants = signal<TontineParticipant[]>([]);
  readonly cycles = signal<TontineCycle[]>([]);
  readonly drawHistory = signal<DrawSession[]>([]);
  readonly beneficiaryList = signal<Beneficiary[]>([]);
  readonly payoutList = signal<Payout[]>([]);
  readonly activity = signal<{ id: string; action: string; description: string; createdAt: string; actorName: string }[]>([]);

  readonly selectedCycleId = signal<string | null>(null);
  readonly lines = signal<ContributionLine[]>([]);
  readonly totals = signal<ContributionTotals | null>(null);
  readonly eligibility = signal<DrawEligibility | null>(null);

  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busy = signal(false);
  readonly tab = signal<Tab>('overview');
  readonly confirm = signal<ConfirmRequest | null>(null);
  readonly paymentTarget = signal<ContributionLine | null>(null);

  private pendingAction: ((reason: string) => void) | null = null;

  readonly tabs: { key: Tab; label: string }[] = [
    { key: 'overview', label: 'Vue générale' },
    { key: 'participants', label: 'Participants' },
    { key: 'cycles', label: 'Cycles' },
    { key: 'contributions', label: 'Cotisations' },
    { key: 'draws', label: 'Tirages' },
    { key: 'beneficiaries', label: 'Bénéficiaires' },
    { key: 'history', label: 'Historique' },
    { key: 'settings', label: 'Paramètres' },
  ];

  readonly tontine = computed<Tontine | null>(() => this.summary()?.tontine ?? null);

  readonly selectedCycle = computed(
    () => this.cycles().find((cycle) => cycle.id === this.selectedCycleId()) ?? null,
  );

  readonly pot = computed(() => {
    const summary = this.summary();
    return summary ? summary.tontine.contributionAmount * summary.participantCount : 0;
  });

  readonly remainingToDraw = computed(
    () => this.participants().filter((p) => !p.hasReceivedPot && p.isActive).length,
  );

  readonly paymentForm = this.fb.nonNullable.group({
    amount: [0, [Validators.required, Validators.min(1)]],
    method: ['cash' as PaymentMethod, Validators.required],
    reference: [''],
    comment: [''],
    paidAt: [today()],
  });

  readonly proofName = signal<string | null>(null);
  private proofUrl: string | null = null;

  /// Réglages modifiables d'une tontine déjà créée.
  ///
  /// Le montant, la fréquence et la date de début restent verrouillés après
  /// activation — les cycles déjà engendrés en dépendent. Les règles du tirage,
  /// elles, se changent à tout moment : c'est ce qui permet d'ouvrir un tirage
  /// sans attendre le règlement de toutes les cotisations.
  readonly settingsForm = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    description: [''],
    dueDay: [5, [Validators.required, Validators.min(1), Validators.max(31)]],
    drawDay: [5, [Validators.required, Validators.min(1), Validators.max(31)]],
    contributionAmount: [0, [Validators.required, Validators.min(1)]],
    requireAllContributionsBeforeDraw: [true],
    allowDrawOverride: [true],
  });

  readonly savingSettings = signal(false);

  readonly isDraft = computed(() => this.tontine()?.status === 'draft');

  constructor() {
    queueMicrotask(() => this.load());
  }

  load(): void {
    const tontineId = this.id();
    this.loading.set(true);
    this.error.set(null);

    forkJoin({
      summary: this.tontines.summary(tontineId),
      participants: this.tontines.participants(tontineId),
      cycles: this.tontines.cycles(tontineId),
      draws: this.draws.history(tontineId),
      beneficiaries: this.beneficiaries.forTontine(tontineId),
      payouts: this.payouts.forTontine(tontineId),
      activity: this.session.organizationId()
        ? this.audit.list(this.session.organizationId()!, {
            tontineId,
            limit: 50,
          })
        : of([]),
    }).subscribe({
      next: (result) => {
        this.summary.set(result.summary);
        this.participants.set(result.participants);
        this.cycles.set(result.cycles);
        this.drawHistory.set(result.draws);
        this.beneficiaryList.set(result.beneficiaries);
        this.payoutList.set(result.payouts);
        this.activity.set(result.activity);
        this.fillSettingsForm(result.summary.tontine);
        this.loading.set(false);

        const current =
          result.summary.currentCycle?.id ?? result.cycles[0]?.id ?? null;
        this.selectCycle(current);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }

  selectCycle(cycleId: string | null): void {
    this.selectedCycleId.set(cycleId);
    if (!cycleId) {
      return;
    }
    const tontineId = this.id();
    this.contributions.forCycle(tontineId, cycleId).subscribe({
      next: (result) => {
        this.lines.set(result.lines);
        this.totals.set(result.totals);
      },
      error: (error: unknown) => this.toast.fromError(error),
    });
    this.draws.eligibility(tontineId, cycleId).subscribe({
      next: (value) => this.eligibility.set(value),
      error: () => this.eligibility.set(null),
    });
  }

  // --- Paiements -----------------------------------------------------------

  openPayment(line: ContributionLine): void {
    this.paymentTarget.set(line);
    this.proofName.set(null);
    this.proofUrl = null;
    this.paymentForm.reset({
      amount: line.remainingAmount || line.expectedAmount,
      method: 'cash',
      reference: '',
      comment: '',
      paidAt: today(),
    });
  }

  onProofSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) {
      return;
    }
    this.payments.uploadProof(file).subscribe({
      next: (attachment) => {
        this.proofUrl = attachment.url;
        this.proofName.set(attachment.fileName);
        this.toast.success('Justificatif téléversé.');
      },
      error: (error: unknown) => this.toast.fromError(error),
    });
  }

  submitPayment(): void {
    const line = this.paymentTarget();
    if (!line || this.paymentForm.invalid || this.busy()) {
      this.paymentForm.markAllAsTouched();
      return;
    }
    const raw = this.paymentForm.getRawValue();
    this.busy.set(true);
    this.payments
      .record(this.id(), {
        cycleId: line.cycleId,
        memberId: line.memberId,
        amount: Number(raw.amount),
        method: raw.method,
        status: 'confirmed',
        reference: raw.reference.trim() || null,
        comment: raw.comment.trim() || null,
        proofUrl: this.proofUrl,
        paidAt: new Date(raw.paidAt).toISOString(),
      })
      .subscribe({
        next: () => {
          this.busy.set(false);
          this.paymentTarget.set(null);
          this.toast.success(`Paiement de ${line.memberName} enregistré.`);
          this.refreshCycle();
        },
        error: (error: unknown) => {
          this.busy.set(false);
          this.toast.fromError(error);
        },
      });
  }

  askConfirmPayment(line: ContributionLine): void {
    const payment = line.payments.find((item) => item.status === 'pending');
    if (!payment) {
      return;
    }
    this.pendingAction = () => {
      this.busy.set(true);
      this.payments.confirm(payment.id).subscribe({
        next: () => {
          this.busy.set(false);
          this.toast.success('Paiement confirmé.');
          this.refreshCycle();
        },
        error: (error: unknown) => {
          this.busy.set(false);
          this.toast.fromError(error);
        },
      });
    };
    this.confirm.set({
      title: 'Confirmer le paiement',
      message: `Le paiement de ${line.memberName} comptera dans la collecte du cycle.`,
      confirmLabel: 'Confirmer',
    });
  }

  askCancelPayment(paymentId: string, memberName: string): void {
    this.pendingAction = (reason) => {
      this.busy.set(true);
      this.payments.cancel(paymentId, reason).subscribe({
        next: () => {
          this.busy.set(false);
          this.toast.success('Paiement annulé — il reste dans l’historique.');
          this.refreshCycle();
        },
        error: (error: unknown) => {
          this.busy.set(false);
          this.toast.fromError(error);
        },
      });
    };
    this.confirm.set({
      title: 'Annuler le paiement',
      message: `Le paiement de ${memberName} cessera de compter dans la collecte. Il restera visible dans l'historique.`,
      confirmLabel: 'Annuler le paiement',
      danger: true,
      reasonLabel: 'Motif',
    });
  }

  // --- Tirage --------------------------------------------------------------

  askRunDraw(force: boolean): void {
    const cycle = this.selectedCycle();
    const eligibility = this.eligibility();
    if (!cycle || !eligibility) {
      return;
    }

    this.pendingAction = (reason) => {
      this.busy.set(true);
      this.draws
        .run(this.id(), cycle.id, force ? { reason } : undefined)
        .subscribe({
          next: (session) => {
            this.busy.set(false);
            this.toast.success(
              `${session.winnerName} est le bénéficiaire de ${session.periodLabel}.`,
            );
            this.load();
            this.tab.set('draws');
          },
          error: (error: unknown) => {
            this.busy.set(false);
            this.toast.fromError(error);
          },
        });
    };

    this.confirm.set(
      force
        ? {
            title: 'Forcer le tirage',
            message: `Des cotisations restent dues (${eligibility.remaining_contributions} pour ${eligibility.remaining_amount}). Le forçage sera enregistré dans le journal d'audit avec votre justification.`,
            confirmLabel: 'Forcer le tirage',
            danger: true,
            reasonLabel: 'Justification',
          }
        : {
            title: 'Lancer le tirage',
            message: `${eligibility.eligible_count} participants éligibles pour ${cycle.periodLabel}. Le bénéficiaire est tiré par le serveur : ni vous ni l'application ne pouvez l'influencer.`,
            confirmLabel: 'Lancer le tirage',
          },
    );
  }

  // --- Versements ----------------------------------------------------------

  askRecordPayout(beneficiary: Beneficiary): void {
    this.pendingAction = () => {
      this.busy.set(true);
      this.payouts
        .record({
          beneficiaryId: beneficiary.id,
          amount: beneficiary.amount,
          method: 'wave',
          status: 'paid',
        })
        .subscribe({
          next: () => {
            this.busy.set(false);
            this.toast.success(`Cagnotte versée à ${beneficiary.memberName}.`);
            this.load();
          },
          error: (error: unknown) => {
            this.busy.set(false);
            this.toast.fromError(error);
          },
        });
    };
    this.confirm.set({
      title: 'Enregistrer le versement',
      message: `${beneficiary.amount} seront enregistrés comme versés à ${beneficiary.memberName}. L'opération est tracée dans l'audit.`,
      confirmLabel: 'Confirmer le versement',
    });
  }

  onConfirmed(reason: string): void {
    const action = this.pendingAction;
    this.pendingAction = null;
    this.confirm.set(null);
    action?.(reason);
  }

  onCancelled(): void {
    this.pendingAction = null;
    this.confirm.set(null);
  }

  private refreshCycle(): void {
    const cycleId = this.selectedCycleId();
    this.tontines.summary(this.id()).subscribe({
      next: (summary) => this.summary.set(summary),
      error: () => undefined,
    });
    this.tontines.cycles(this.id()).subscribe({
      next: (cycles) => this.cycles.set(cycles),
      error: () => undefined,
    });
    if (cycleId) {
      this.selectCycle(cycleId);
    }
  }

  beneficiaryOfCycle(cycleId: string): Beneficiary | undefined {
    return this.beneficiaryList().find((item) => item.cycleId === cycleId);
  }

  beneficiaryPeriod(cycleId: string): string {
    return this.cycles().find((cycle) => cycle.id === cycleId)?.periodLabel ?? '—';
  }

  payoutOfBeneficiary(beneficiaryId: string): Payout | undefined {
    return this.payoutList().find((item) => item.beneficiaryId === beneficiaryId);
  }

  pendingPayment(line: ContributionLine): boolean {
    return line.payments.some((payment) => payment.status === 'pending');
  }

  invalidSetting(
    field: 'name' | 'dueDay' | 'drawDay' | 'contributionAmount',
  ): boolean {
    const control = this.settingsForm.controls[field];
    return control.invalid && (control.touched || control.dirty);
  }

  resetSettings(): void {
    const tontine = this.tontine();
    if (tontine) {
      this.fillSettingsForm(tontine);
    }
  }

  submitSettings(): void {
    const tontine = this.tontine();
    if (!tontine || this.settingsForm.invalid || this.savingSettings()) {
      this.settingsForm.markAllAsTouched();
      return;
    }

    const raw = this.settingsForm.getRawValue();
    const changes: Record<string, unknown> = {
      name: raw.name.trim(),
      description: raw.description.trim() || null,
      dueDayOfPeriod: raw.dueDay,
      drawDayOfPeriod: raw.drawDay,
      requireAllContributionsBeforeDraw: raw.requireAllContributionsBeforeDraw,
      allowDrawOverride: raw.allowDrawOverride,
    };
    // Le serveur refuse un montant sur une tontine activée : ne l'envoyer que
    // tant qu'elle est en brouillon, plutôt que d'essuyer un 409.
    if (this.isDraft()) {
      changes['contributionAmount'] = raw.contributionAmount;
    }

    this.savingSettings.set(true);
    this.tontines.update(tontine.id, changes).subscribe({
      next: () => {
        this.savingSettings.set(false);
        this.toast.success('Tontine mise à jour.');
        this.load();
      },
      error: (error: unknown) => {
        this.savingSettings.set(false);
        this.toast.fromError(error);
      },
    });
  }

  private fillSettingsForm(tontine: Tontine): void {
    this.settingsForm.reset({
      name: tontine.name,
      description: tontine.description ?? '',
      dueDay: tontine.dueDayOfPeriod,
      drawDay: tontine.drawDayOfPeriod,
      contributionAmount: tontine.contributionAmount,
      requireAllContributionsBeforeDraw:
        tontine.requireAllContributionsBeforeDraw,
      allowDrawOverride: tontine.allowDrawOverride,
    });
    // Désactiver le contrôle plutôt que l'attribut HTML : c'est le formulaire
    // qui fait foi, et Angular avertit quand les deux divergent.
    const amount = this.settingsForm.controls.contributionAmount;
    if (tontine.status === 'draft') {
      amount.enable({ emitEvent: false });
    } else {
      amount.disable({ emitEvent: false });
    }
  }
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}
