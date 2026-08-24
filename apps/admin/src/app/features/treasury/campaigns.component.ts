import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import {
  AmountMode,
  CampaignEntry,
  Cashbox,
  ContributionCampaign,
  ContributionType,
  Member,
} from '../../core/models/domain.models';
import { FrDatePipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { MemberService } from '../../core/services/domain.services';
import {
  CampaignService,
  CashboxService,
} from '../../core/services/rbac-treasury.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  ConfirmDialog,
  ConfirmRequest,
  PageHeader,
  SearchInput,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

const TYPES: { value: ContributionType; label: string; hint: string }[] = [
  {
    value: 'association',
    label: 'Associative',
    hint: 'Fonctionnement de l\'association. Les fonds vont dans une caisse.',
  },
  {
    value: 'exceptional',
    label: 'Exceptionnelle',
    hint: 'Mariage, décès, naissance, événement, projet commun.',
  },
  {
    value: 'voluntary',
    label: 'Volontaire',
    hint: 'Participation libre : chacun donne ce qu\'il veut.',
  },
];

const METHODS = [
  { value: 'cash', label: 'Espèces' },
  { value: 'wave', label: 'Wave' },
  { value: 'orange_money', label: 'Orange Money' },
  { value: 'mtn_momo', label: 'MTN MoMo' },
  { value: 'moov_money', label: 'Moov Money' },
  { value: 'bank_transfer', label: 'Virement' },
  { value: 'other', label: 'Autre' },
];

/** Cotisations associatives, exceptionnelles et volontaires.
 *
 *  Les cotisations de tontine ne sont pas ici : elles alimentent la cagnotte
 *  d'un cycle et se consultent depuis la tontine.
 */
@Component({
  selector: 'app-campaigns',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FrDatePipe,
    MoneyPipe,
    ConfirmDialog,
    PageHeader,
    SearchInput,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  templateUrl: './campaigns.component.html',
})
export class CampaignsPage {
  private readonly campaigns = inject(CampaignService);
  private readonly cashboxes = inject(CashboxService);
  private readonly members = inject(MemberService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly types = TYPES;
  readonly methods = METHODS;

  readonly list = signal<ContributionCampaign[]>([]);
  readonly boxes = signal<Cashbox[]>([]);
  readonly roster = signal<Member[]>([]);
  readonly selected = signal<ContributionCampaign | null>(null);
  readonly entries = signal<CampaignEntry[]>([]);
  readonly search = signal('');
  readonly statusFilter = signal<string>('');
  readonly typeFilter = signal<string>('');

  readonly loading = signal(true);
  readonly loadingDetail = signal(false);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly formOpen = signal(false);
  readonly payingId = signal<string | null>(null);
  readonly confirm = signal<ConfirmRequest | null>(null);

  /** Membres cochés dans le formulaire de création. */
  readonly chosen = signal<Set<string>>(new Set());

  readonly form = this.fb.nonNullable.group({
    title: ['', [Validators.required, Validators.minLength(2)]],
    description: [''],
    contributionType: ['association' as ContributionType, Validators.required],
    amountMode: ['fixed' as AmountMode, Validators.required],
    amount: [0],
    dueDate: [''],
    cashboxId: [''],
    mandatory: [true],
    penaltyEnabled: [false],
    penaltyAmount: [0],
  });

  readonly payForm = this.fb.nonNullable.group({
    amount: [0, [Validators.required, Validators.min(1)]],
    paymentMethod: ['cash', Validators.required],
    reference: [''],
    comment: [''],
  });

  readonly filtered = computed(() => {
    const needle = this.search().trim().toLowerCase();
    return this.list().filter(
      (campaign) => !needle || campaign.title.toLowerCase().includes(needle),
    );
  });

  /** Lignes du suivi individuel, filtrées par la recherche. */
  readonly visibleEntries = computed(() => {
    const needle = this.search().trim().toLowerCase();
    return this.entries().filter(
      (entry) => !needle || entry.memberName.toLowerCase().includes(needle),
    );
  });

  readonly freeAmount = computed(
    () => this.form.controls.amountMode.value === 'free',
  );

  constructor() {
    this.load();
  }

  load(): void {
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      this.loading.set(false);
      return;
    }
    this.loading.set(true);
    this.error.set(null);

    this.campaigns
      .list(organizationId, {
        status: (this.statusFilter() || null) as never,
        type: (this.typeFilter() || null) as never,
      })
      .subscribe({
        next: (body) => {
          this.list.set(body.items);
          this.loading.set(false);
        },
        error: (cause) => {
          this.error.set(describeError(cause));
          this.loading.set(false);
        },
      });

    this.cashboxes.list(organizationId).subscribe({
      next: (boxes) => this.boxes.set(boxes.filter((box) => box.status === 'open')),
      error: () => {
        // La liste reste utilisable : la caisse par défaut sera choisie par
        // le backend si aucune n'est indiquée.
      },
    });
  }

  onFilter(): void {
    this.load();
  }

  openDetail(campaign: ContributionCampaign): void {
    this.loadingDetail.set(true);
    this.campaigns.byId(campaign.id).subscribe({
      next: (full) => {
        this.selected.set(full);
        this.entries.set(full.entries ?? []);
        this.loadingDetail.set(false);
      },
      error: (cause) => {
        this.loadingDetail.set(false);
        this.toast.error(describeError(cause));
      },
    });
  }

  closeDetail(): void {
    this.selected.set(null);
    this.entries.set([]);
    this.payingId.set(null);
  }

  // --- Création --------------------------------------------------------------

  openCreate(): void {
    const organizationId = this.session.organizationId();
    this.form.reset({
      title: '',
      description: '',
      contributionType: 'association',
      amountMode: 'fixed',
      amount: 0,
      dueDate: '',
      cashboxId: this.boxes().find((box) => box.isDefault)?.id ?? '',
      mandatory: true,
      penaltyEnabled: false,
      penaltyAmount: 0,
    });
    this.chosen.set(new Set());
    this.formOpen.set(true);

    if (organizationId && !this.roster().length) {
      this.members
        .list(organizationId, { status: 'active', pageSize: 200 })
        .subscribe({
          next: (page) => this.roster.set(page.items),
          error: (cause) => this.toast.error(describeError(cause)),
        });
    }
  }

  toggleMember(memberId: string): void {
    this.chosen.update((current) => {
      const next = new Set(current);
      if (next.has(memberId)) {
        next.delete(memberId);
      } else {
        next.add(memberId);
      }
      return next;
    });
  }

  isChosen(memberId: string): boolean {
    return this.chosen().has(memberId);
  }

  toggleAll(): void {
    const all = this.roster().map((member) => member.id);
    this.chosen.update((current) =>
      current.size === all.length ? new Set() : new Set(all),
    );
  }

  create(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }
    const raw = this.form.getRawValue();
    if (raw.amountMode === 'fixed' && raw.amount <= 0) {
      this.toast.error('Une cotisation à montant fixe demande un montant.');
      return;
    }

    this.saving.set(true);
    this.campaigns
      .create(organizationId, {
        title: raw.title,
        description: raw.description || null,
        contributionType: raw.contributionType,
        amountMode: raw.amountMode,
        amount: raw.amountMode === 'fixed' ? raw.amount : 0,
        dueDate: raw.dueDate ? new Date(raw.dueDate).toISOString() : null,
        // Aucun membre coché : tous les membres actifs sont concernés.
        memberIds: this.chosen().size ? [...this.chosen()] : null,
        cashboxId: raw.cashboxId || null,
        mandatory: raw.mandatory,
        penaltyEnabled: raw.penaltyEnabled,
        penaltyAmount: raw.penaltyAmount,
      })
      .subscribe({
        next: (campaign) => {
          this.list.update((current) => [campaign, ...current]);
          this.formOpen.set(false);
          this.saving.set(false);
          this.toast.success('Cotisation créée et notifiée aux membres.');
          this.openDetail(campaign);
        },
        error: (cause) => {
          this.saving.set(false);
          this.toast.error(describeError(cause));
        },
      });
  }

  // --- Règlement -------------------------------------------------------------

  openPayment(entry: CampaignEntry): void {
    this.payingId.set(entry.id);
    this.payForm.reset({
      amount: entry.remainingAmount || 0,
      paymentMethod: 'cash',
      reference: '',
      comment: '',
    });
  }

  pay(entry: CampaignEntry): void {
    if (this.payForm.invalid) {
      this.payForm.markAllAsTouched();
      return;
    }
    this.saving.set(true);
    this.campaigns.pay(entry.id, this.payForm.getRawValue()).subscribe({
      next: (body) => {
        // Une saisie, sept effets : le suivi, le solde et l'audit ont déjà
        // bougé côté serveur. On relit la campagne plutôt que d'extrapoler.
        this.entries.update((list) =>
          list.map((item) => (item.id === body.entry.id ? body.entry : item)),
        );
        this.payingId.set(null);
        this.saving.set(false);
        this.toast.success('Paiement enregistré et porté en caisse.');
        this.refreshSelected();
      },
      error: (cause) => {
        this.saving.set(false);
        this.toast.error(describeError(cause));
      },
    });
  }

  askExempt(entry: CampaignEntry): void {
    this.pendingEntry = entry;
    this.confirm.set({
      title: `Exempter ${entry.memberName}`,
      message:
        "La ligne sortira de l'attendu : elle ne comptera plus comme impayé " +
        'et ne faussera pas le taux de recouvrement.',
      confirmLabel: 'Exempter',
      reasonLabel: 'Motif',
    });
  }

  private pendingEntry: CampaignEntry | null = null;

  onConfirmed(reason: string): void {
    const entry = this.pendingEntry;
    this.pendingEntry = null;
    this.confirm.set(null);
    if (!entry) {
      return;
    }
    this.campaigns.exempt(entry.id, reason).subscribe({
      next: (updated) => {
        this.entries.update((list) =>
          list.map((item) => (item.id === updated.id ? updated : item)),
        );
        this.toast.success('Membre exempté.');
        this.refreshSelected();
      },
      error: (cause) => this.toast.error(describeError(cause)),
    });
  }

  onCancelled(): void {
    this.pendingEntry = null;
    this.confirm.set(null);
  }

  private refreshSelected(): void {
    const campaign = this.selected();
    if (!campaign) {
      return;
    }
    this.campaigns.byId(campaign.id).subscribe({
      next: (full) => {
        this.selected.set(full);
        this.entries.set(full.entries ?? []);
        this.list.update((current) =>
          current.map((item) => (item.id === full.id ? full : item)),
        );
      },
      error: () => this.load(),
    });
  }

  typeLabel(value: string): string {
    return TYPES.find((item) => item.value === value)?.label ?? value;
  }

  cashboxName(id: string | null): string {
    if (!id) {
      return 'Caisse par défaut';
    }
    return this.boxes().find((box) => box.id === id)?.name ?? 'Caisse';
  }
}
