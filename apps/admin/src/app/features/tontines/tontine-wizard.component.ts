import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';

import {
  AllocationMode,
  Member,
  TontineFrequency,
} from '../../core/models/domain.models';
import { LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { MemberService, TontineService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import { PageHeader, StateView, UserAvatar } from '../../shared/ui.components';

const STEPS = [
  'Informations',
  'Participants',
  "Mode d'attribution",
  'Règles',
  'Récapitulatif',
];

@Component({
  selector: 'app-tontine-wizard',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    StateView,
    UserAvatar,
  ],
  templateUrl: './tontine-wizard.component.html',
})
export class TontineWizardPage {
  private readonly fb = inject(FormBuilder);
  private readonly members = inject(MemberService);
  private readonly tontines = inject(TontineService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);
  readonly session = inject(SessionService);

  readonly steps = STEPS;
  readonly step = signal(0);
  readonly saving = signal(false);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly candidates = signal<Member[]>([]);
  readonly selected = signal<Set<string>>(new Set());

  readonly frequencies: TontineFrequency[] = ['monthly', 'biweekly', 'weekly'];
  readonly modes: AllocationMode[] = [
    'monthly_draw',
    'full_order_draw',
    'manual_order',
  ];

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    description: [''],
    contributionAmount: [50000, [Validators.required, Validators.min(1)]],
    frequency: ['monthly' as TontineFrequency, Validators.required],
    startDate: [defaultStartDate(), Validators.required],
    dueDayOfPeriod: [5, [Validators.required, Validators.min(1), Validators.max(31)]],
    allocationMode: ['monthly_draw' as AllocationMode, Validators.required],
    requireAllContributionsBeforeDraw: [true],
    allowDrawOverride: [true],
  });

  readonly participantCount = computed(() => this.selected().size);

  readonly pot = computed(
    () => this.form.controls.contributionAmount.value * this.participantCount(),
  );

  /** L'ordre manuel se saisit après création, depuis l'onglet Participants. */
  readonly orderNotice = computed(
    () => this.form.controls.allocationMode.value === 'manual_order',
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
    this.members.list(organizationId, { pageSize: 200 }).subscribe({
      next: (page) => {
        this.candidates.set(page.items.filter((member) => member.status === 'active'));
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }

  toggle(memberId: string): void {
    this.selected.update((current) => {
      const next = new Set(current);
      if (next.has(memberId)) {
        next.delete(memberId);
      } else {
        next.add(memberId);
      }
      return next;
    });
  }

  selectAll(): void {
    this.selected.set(new Set(this.candidates().map((member) => member.id)));
  }

  clearSelection(): void {
    this.selected.set(new Set());
  }

  isSelected(memberId: string): boolean {
    return this.selected().has(memberId);
  }

  canContinue(): boolean {
    switch (this.step()) {
      case 0:
        return (
          this.form.controls.name.valid &&
          this.form.controls.contributionAmount.valid &&
          this.form.controls.startDate.valid
        );
      case 1:
        return this.participantCount() >= 2;
      default:
        return true;
    }
  }

  next(): void {
    if (!this.canContinue()) {
      this.form.markAllAsTouched();
      return;
    }
    this.step.update((value) => Math.min(STEPS.length - 1, value + 1));
  }

  previous(): void {
    this.step.update((value) => Math.max(0, value - 1));
  }

  submit(): void {
    const organizationId = this.session.organizationId();
    if (!organizationId || this.saving()) {
      return;
    }
    if (this.form.invalid || this.participantCount() < 2) {
      this.toast.error('Complétez les informations et choisissez au moins 2 participants.');
      return;
    }

    this.saving.set(true);
    const raw = this.form.getRawValue();

    this.tontines
      .create(organizationId, {
        name: raw.name.trim(),
        description: raw.description.trim() || null,
        contributionAmount: Number(raw.contributionAmount),
        currency: this.session.currency(),
        frequency: raw.frequency,
        allocationMode: raw.allocationMode,
        startDate: raw.startDate,
        dueDayOfPeriod: Number(raw.dueDayOfPeriod),
        memberIds: [...this.selected()],
        requireAllContributionsBeforeDraw: raw.requireAllContributionsBeforeDraw,
        allowDrawOverride: raw.allowDrawOverride,
      })
      .subscribe({
        next: (tontine) => {
          this.saving.set(false);
          this.toast.success(
            `« ${tontine.name} » créée : les cycles et les cotisations sont générés.`,
          );
          void this.router.navigate(['/tontines', tontine.id]);
        },
        error: (error: unknown) => {
          this.saving.set(false);
          this.toast.fromError(error);
        },
      });
  }
}

function defaultStartDate(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
}
