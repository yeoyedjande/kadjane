import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import {
  Cashbox,
  CashboxTransaction,
  CashMovementType,
} from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { CashboxService } from '../../core/services/rbac-treasury.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  ConfirmDialog,
  ConfirmRequest,
  PageHeader,
  Pagination,
  StatCard,
  StateView,
  StatusBadge,
} from '../../shared/ui.components';

const PAGE_SIZE = 25;

const CATEGORIES: { value: string; label: string; type: CashMovementType }[] = [
  { value: 'contribution', label: 'Cotisation', type: 'income' },
  { value: 'penalty', label: 'Pénalité', type: 'income' },
  { value: 'donation', label: 'Don', type: 'income' },
  { value: 'refund', label: 'Remboursement', type: 'income' },
  { value: 'social_aid', label: 'Aide sociale', type: 'expense' },
  { value: 'event', label: 'Événement', type: 'expense' },
  { value: 'administrative', label: 'Dépense administrative', type: 'expense' },
  { value: 'fee', label: 'Frais', type: 'expense' },
  { value: 'other', label: 'Autre', type: 'income' },
];

/** Caisses de l'association et leur journal.
 *
 *  Le solde affiché vient du backend : il n'est jamais recalculé ici, et il
 *  n'existe pas de colonne de solde en base — c'est le journal qui fait foi.
 */
@Component({
  selector: 'app-cashboxes',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FrDatePipe,
    LabelPipe,
    MoneyPipe,
    ConfirmDialog,
    PageHeader,
    Pagination,
    StatCard,
    StateView,
    StatusBadge,
  ],
  templateUrl: './cashboxes.component.html',
})
export class CashboxesPage {
  private readonly cashboxes = inject(CashboxService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly boxes = signal<Cashbox[]>([]);
  readonly selectedId = signal<string | null>(null);
  readonly transactions = signal<CashboxTransaction[]>([]);
  readonly total = signal(0);
  readonly page = signal(0);

  readonly loading = signal(true);
  readonly loadingJournal = signal(false);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly createOpen = signal(false);
  readonly movementOpen = signal(false);
  readonly confirm = signal<ConfirmRequest | null>(null);

  readonly pageSize = PAGE_SIZE;
  readonly categories = CATEGORIES;

  readonly selected = computed(
    () => this.boxes().find((box) => box.id === this.selectedId()) ?? null,
  );

  /** Somme des soldes : le vrai « combien l'association détient ». */
  readonly globalBalance = computed(() =>
    this.boxes().reduce((sum, box) => sum + box.currentBalance, 0),
  );

  readonly createForm = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    description: [''],
    openingBalance: [0, [Validators.min(0)]],
    isDefault: [false],
  });

  readonly movementForm = this.fb.nonNullable.group({
    type: ['income' as CashMovementType, Validators.required],
    category: ['donation', Validators.required],
    amount: [0, [Validators.required, Validators.min(1)]],
    description: [''],
    reference: [''],
  });

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
    this.cashboxes.list(organizationId).subscribe({
      next: (boxes) => {
        this.boxes.set(boxes);
        const current = this.selectedId();
        const keep = boxes.some((box) => box.id === current);
        this.select(keep ? (current as string) : (boxes[0]?.id ?? null));
        this.loading.set(false);
      },
      error: (cause) => {
        this.error.set(describeError(cause));
        this.loading.set(false);
      },
    });
  }

  select(cashboxId: string | null): void {
    this.selectedId.set(cashboxId);
    this.page.set(0);
    this.transactions.set([]);
    this.total.set(0);
    if (cashboxId) {
      this.loadJournal();
    }
  }

  loadJournal(): void {
    const cashboxId = this.selectedId();
    if (!cashboxId) {
      return;
    }
    this.loadingJournal.set(true);
    this.cashboxes
      .transactions(cashboxId, {
        limit: PAGE_SIZE,
        offset: this.page() * PAGE_SIZE,
      })
      .subscribe({
        next: (body) => {
          this.transactions.set(body.items);
          this.total.set(body.total);
          this.loadingJournal.set(false);
        },
        error: (cause) => {
          this.loadingJournal.set(false);
          this.toast.error(describeError(cause));
        },
      });
  }

  goToPage(page: number): void {
    this.page.set(page);
    this.loadJournal();
  }

  // --- Création d'une caisse -------------------------------------------------

  openCreate(): void {
    this.createForm.reset({
      name: '',
      description: '',
      openingBalance: 0,
      isDefault: false,
    });
    this.createOpen.set(true);
  }

  create(): void {
    if (this.createForm.invalid) {
      this.createForm.markAllAsTouched();
      return;
    }
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }
    this.saving.set(true);
    this.cashboxes.create(organizationId, this.createForm.getRawValue()).subscribe({
      next: (box) => {
        this.boxes.update((list) => [...list, box]);
        this.select(box.id);
        this.createOpen.set(false);
        this.saving.set(false);
        this.toast.success('Caisse ouverte.');
      },
      error: (cause) => {
        this.saving.set(false);
        this.toast.error(describeError(cause));
      },
    });
  }

  // --- Mouvements ------------------------------------------------------------

  openMovement(type: CashMovementType): void {
    this.movementForm.reset({
      type,
      category: type === 'income' ? 'donation' : 'event',
      amount: 0,
      description: '',
      reference: '',
    });
    this.movementOpen.set(true);
  }

  /** Catégories proposées : celles qui ont un sens pour le type choisi. */
  categoriesFor(type: CashMovementType): typeof CATEGORIES {
    if (type === 'transfer' || type === 'adjustment') {
      return CATEGORIES;
    }
    return CATEGORIES.filter(
      (item) => item.type === type || item.value === 'other',
    );
  }

  record(): void {
    if (this.movementForm.invalid) {
      this.movementForm.markAllAsTouched();
      return;
    }
    const cashbox = this.selected();
    if (!cashbox) {
      return;
    }
    this.saving.set(true);
    this.cashboxes.record(cashbox.id, this.movementForm.getRawValue()).subscribe({
      next: () => {
        this.movementOpen.set(false);
        this.saving.set(false);
        this.toast.success('Mouvement enregistré.');
        // Le solde a changé : on relit la caisse plutôt que d'additionner ici.
        this.refresh(cashbox.id);
      },
      error: (cause) => {
        this.saving.set(false);
        this.toast.error(describeError(cause));
      },
    });
  }

  /** §34 : confirmation avant annulation d'une écriture. */
  askCancel(transaction: CashboxTransaction): void {
    this.pending = transaction;
    this.confirm.set({
      title: 'Annuler ce mouvement',
      message:
        "L'écriture sortira du solde mais restera au journal et dans l'audit. " +
        'Aucune donnée financière n\'est supprimée.',
      confirmLabel: 'Annuler le mouvement',
      danger: true,
      reasonLabel: 'Motif',
    });
  }

  private pending: CashboxTransaction | null = null;

  onConfirmed(reason: string): void {
    const transaction = this.pending;
    this.pending = null;
    this.confirm.set(null);
    if (!transaction) {
      return;
    }
    this.cashboxes.cancelTransaction(transaction.id, reason).subscribe({
      next: () => {
        this.toast.success('Mouvement annulé.');
        this.refresh(transaction.cashboxId ?? this.selectedId());
      },
      error: (cause) => this.toast.error(describeError(cause)),
    });
  }

  onCancelled(): void {
    this.pending = null;
    this.confirm.set(null);
  }

  askClose(cashbox: Cashbox): void {
    this.pendingClose = cashbox;
    this.confirm.set({
      title: `Fermer « ${cashbox.name} »`,
      message:
        `Solde résiduel : ${cashbox.currentBalance}. La caisse n'acceptera ` +
        'plus aucun mouvement. Le solde reste lisible — fermer ne fait pas ' +
        "disparaître l'argent.",
      confirmLabel: 'Fermer la caisse',
      danger: true,
    });
  }

  private pendingClose: Cashbox | null = null;

  confirmClose(): void {
    const cashbox = this.pendingClose;
    this.pendingClose = null;
    this.confirm.set(null);
    if (!cashbox) {
      return;
    }
    this.cashboxes.close(cashbox.id).subscribe({
      next: (updated) => {
        this.boxes.update((list) =>
          list.map((item) => (item.id === updated.id ? updated : item)),
        );
        this.toast.success('Caisse fermée.');
      },
      error: (cause) => this.toast.error(describeError(cause)),
    });
  }

  /** Route la confirmation vers la bonne action selon ce qui est en attente. */
  dispatch(reason: string): void {
    if (this.pendingClose) {
      this.confirmClose();
      return;
    }
    this.onConfirmed(reason);
  }

  private refresh(cashboxId: string | null): void {
    if (!cashboxId) {
      return;
    }
    this.cashboxes.byId(cashboxId).subscribe({
      next: (box) =>
        this.boxes.update((list) =>
          list.map((item) => (item.id === box.id ? box : item)),
        ),
      error: () => this.load(),
    });
    this.loadJournal();
  }
}
