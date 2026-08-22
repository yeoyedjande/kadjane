import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import {
  DuesEntry,
  DuesPlan,
  DuesPlanPayload,
  TontineFrequency,
} from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { DuesService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  SearchInput,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

const FREQUENCIES: { value: TontineFrequency; label: string }[] = [
  { value: 'monthly', label: 'Mensuelle' },
  { value: 'weekly', label: 'Hebdomadaire' },
  { value: 'biweekly', label: 'Quinzaine' },
];

/** Caisse de l'association : cotisations dues hors tontine.
 *
 *  Le trésorier voit qui a réglé, qui doit encore, et encaisse. C'est du
 *  pilotage : l'application mobile, elle, ne montre au membre que sa propre
 *  situation.
 */
@Component({
  selector: 'app-dues',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FrDatePipe,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    SearchInput,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  templateUrl: './dues.component.html',
})
export class DuesPage {
  private readonly dues = inject(DuesService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly frequencies = FREQUENCIES;

  readonly plans = signal<DuesPlan[]>([]);
  readonly selectedId = signal<string | null>(null);
  readonly entries = signal<DuesEntry[]>([]);
  readonly search = signal('');
  readonly onlyUnpaid = signal(false);

  readonly loading = signal(true);
  readonly loadingEntries = signal(false);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly formOpen = signal(false);
  readonly payingId = signal<string | null>(null);

  readonly selected = computed(
    () => this.plans().find((plan) => plan.id === this.selectedId()) ?? null,
  );

  /** Périodes présentes, la plus récente d'abord. */
  readonly periods = computed(() => {
    const seen = new Map<number, string>();
    for (const entry of this.entries()) {
      seen.set(entry.sequenceNumber, entry.periodLabel);
    }
    return [...seen.entries()]
      .sort((a, b) => b[0] - a[0])
      .map(([sequence, label]) => ({ sequence, label }));
  });

  readonly period = signal<number | null>(null);

  readonly visibleEntries = computed(() => {
    const term = this.search().trim().toLowerCase();
    const periodFilter = this.period();
    return this.entries().filter((entry) => {
      if (periodFilter !== null && entry.sequenceNumber !== periodFilter) {
        return false;
      }
      if (this.onlyUnpaid() && entry.status === 'paid') {
        return false;
      }
      if (!term) {
        return true;
      }
      const user = entry.member?.user;
      const name = `${user?.firstName ?? ''} ${user?.lastName ?? ''}`.toLowerCase();
      return name.includes(term) || (user?.phone ?? '').includes(term);
    });
  });

  /** Totaux de ce qui est affiché — le trésorier compare avec sa caisse. */
  readonly totals = computed(() => {
    const rows = this.visibleEntries();
    return {
      expected: rows.reduce((sum, e) => sum + Number(e.expectedAmount), 0),
      collected: rows.reduce((sum, e) => sum + Number(e.paidAmount), 0),
      unpaid: rows.filter((e) => e.status !== 'paid').length,
    };
  });

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    amount: [5000, [Validators.required, Validators.min(1)]],
    frequency: ['monthly' as TontineFrequency, Validators.required],
    dueDay: [5, [Validators.required, Validators.min(1), Validators.max(31)]],
    description: [''],
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
    this.dues.plans(organizationId).subscribe({
      next: (plans) => {
        this.plans.set(plans);
        this.loading.set(false);
        const current = this.selectedId();
        const stillThere = plans.some((plan) => plan.id === current);
        if (plans.length && !stillThere) {
          this.select(plans[0].id);
        } else if (current) {
          this.loadEntries(current);
        }
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }

  select(planId: string): void {
    this.selectedId.set(planId);
    this.period.set(null);
    this.loadEntries(planId);
  }

  private loadEntries(planId: string): void {
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }
    this.loadingEntries.set(true);
    this.dues.entries(organizationId, planId).subscribe({
      next: (entries) => {
        this.entries.set(entries);
        this.loadingEntries.set(false);
        // Par défaut, la période la plus récente : c'est celle qu'on relance.
        if (this.period() === null && entries.length) {
          this.period.set(Math.max(...entries.map((e) => e.sequenceNumber)));
        }
      },
      error: (error: unknown) => {
        this.loadingEntries.set(false);
        this.toast.fromError(error);
      },
    });
  }

  onPeriod(value: string): void {
    this.period.set(value === '' ? null : Number(value));
  }

  toggleUnpaid(): void {
    this.onlyUnpaid.update((value) => !value);
  }

  openCreate(): void {
    this.form.reset({
      amount: 5000,
      frequency: 'monthly',
      dueDay: 5,
      name: '',
      description: '',
    });
    this.formOpen.set(true);
  }

  submit(): void {
    if (this.form.invalid || this.saving()) {
      this.form.markAllAsTouched();
      return;
    }
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }
    const raw = this.form.getRawValue();
    const payload: DuesPlanPayload = {
      name: raw.name.trim(),
      amount: raw.amount,
      frequency: raw.frequency,
      dueDay: raw.dueDay,
      description: raw.description.trim() || null,
    };

    this.saving.set(true);
    this.dues.createPlan(organizationId, payload).subscribe({
      next: (plan) => {
        this.saving.set(false);
        this.formOpen.set(false);
        this.toast.success(`Cotisation « ${plan.name} » créée.`);
        this.selectedId.set(plan.id);
        this.load();
      },
      error: (error: unknown) => {
        this.saving.set(false);
        this.toast.fromError(error);
      },
    });
  }

  /** Encaisse le reste dû sur une échéance. */
  settle(entry: DuesEntry): void {
    if (this.payingId()) {
      return;
    }
    this.payingId.set(entry.id);
    this.dues
      .recordPayment(entry.id, {
        amount: Number(entry.remainingAmount),
        paymentMethod: 'cash',
      })
      .subscribe({
        next: () => {
          this.payingId.set(null);
          const user = entry.member?.user;
          this.toast.success(
            `Règlement enregistré pour ${user?.firstName ?? 'ce membre'}.`,
          );
          this.load();
        },
        error: (error: unknown) => {
          this.payingId.set(null);
          this.toast.fromError(error);
        },
      });
  }

  invalid(control: string): boolean {
    const field = (this.form.controls as Record<string, any>)[control];
    return field?.invalid && (field.touched || field.dirty);
  }
}
