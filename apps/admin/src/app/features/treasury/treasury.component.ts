import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { forkJoin } from 'rxjs';

import {
  ReportSnapshot,
  TransactionType,
  TreasurySnapshot,
} from '../../core/models/domain.models';
import { AmountPipe, FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { TreasuryService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  StatCard,
  StateView,
  StatusBadge,
} from '../../shared/ui.components';

const CATEGORIES = ['donation', 'fee', 'event', 'social_aid', 'other'];

@Component({
  selector: 'app-treasury',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    AmountPipe,
    FrDatePipe,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    StatCard,
    StateView,
    StatusBadge,
  ],
  template: `
    <k-page-header
      title="Trésorerie"
      subtitle="Cotisations encaissées, cagnottes versées et mouvements de caisse."
    >
      @if (session.can('treasury.manage')) {
        <button type="button" class="k-btn" (click)="formOpen.set(!formOpen())">
          {{ formOpen() ? 'Fermer' : 'Nouveau mouvement' }}
        </button>
      }
    </k-page-header>

    <k-state [loading]="loading()" [error]="error()" (retry)="load()" />

    @if (treasury(); as treasury) {
      <div class="k-stack">
        <section class="k-grid k-grid--3">
          <k-stat label="Solde" [value]="treasury.balance | money" [accent]="true" />
          <k-stat label="Entrées" [value]="treasury.inflows | money" />
          <k-stat label="Sorties" [value]="treasury.outflows | money" />
        </section>

        @if (formOpen()) {
          <article class="k-card">
            <div class="k-card__header">
              <h2 class="k-card__title">Enregistrer un mouvement de caisse</h2>
            </div>
            <form class="k-card__body k-stack" [formGroup]="form" (ngSubmit)="submit()">
              <div class="k-grid k-grid--4">
                <label class="k-field">
                  <span class="k-label">Sens</span>
                  <select class="k-select" formControlName="type">
                    <option value="income">Entrée</option>
                    <option value="expense">Sortie</option>
                  </select>
                </label>
                <label class="k-field">
                  <span class="k-label">Catégorie</span>
                  <select class="k-select" formControlName="category">
                    @for (category of categories; track category) {
                      <option [value]="category">{{ category | label }}</option>
                    }
                  </select>
                </label>
                <label class="k-field">
                  <span class="k-label">Montant</span>
                  <input class="k-input" type="number" min="1" formControlName="amount" />
                </label>
                <label class="k-field">
                  <span class="k-label">Description</span>
                  <input class="k-input" formControlName="description" />
                </label>
              </div>
              <div class="k-row" style="justify-content: flex-end">
                <button type="submit" class="k-btn" [disabled]="saving()">
                  {{ saving() ? 'Enregistrement…' : 'Enregistrer' }}
                </button>
              </div>
            </form>
          </article>
        }

        @if (report(); as report) {
          <article class="k-card">
            <div class="k-card__header">
              <h2 class="k-card__title">Rapport par tontine</h2>
              <span class="k-tertiary" style="font-size: 12.5px">
                Attendu {{ report.totalExpected | money }} · Collecté
                {{ report.totalCollected | money }} · Distribué
                {{ report.totalDistributed | money }}
              </span>
            </div>
            @if (report.lines.length === 0) {
              <div class="k-card__body"><p class="k-muted">Aucune tontine.</p></div>
            } @else {
              <div class="k-table-wrap">
                <table class="k-table">
                  <thead>
                    <tr>
                      <th>Tontine</th>
                      <th>Statut</th>
                      <th class="k-num">Participants</th>
                      <th class="k-num">Attendu</th>
                      <th class="k-num">Collecté</th>
                      <th class="k-num">Distribué</th>
                    </tr>
                  </thead>
                  <tbody>
                    @for (line of report.lines; track line.tontineId) {
                      <tr>
                        <td class="k-strong">{{ line.tontineName }}</td>
                        <td><k-badge [value]="line.status" /></td>
                        <td class="k-num">{{ line.participants }}</td>
                        <td class="k-num">{{ line.expected | amount }}</td>
                        <td class="k-num">{{ line.collected | amount }}</td>
                        <td class="k-num">{{ line.distributed | amount }}</td>
                      </tr>
                    }
                  </tbody>
                </table>
              </div>
            }
          </article>
        }

        <article class="k-card">
          <div class="k-card__header"><h2 class="k-card__title">Mouvements</h2></div>
          @if (treasury.transactions.length === 0) {
            <div class="k-card__body"><p class="k-muted">Aucun mouvement.</p></div>
          } @else {
            <div class="k-table-wrap">
              <table class="k-table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Description</th>
                    <th>Catégorie</th>
                    <th>Origine</th>
                    <th class="k-num">Montant</th>
                  </tr>
                </thead>
                <tbody>
                  @for (transaction of treasury.transactions; track transaction.id) {
                    <tr>
                      <td class="k-nowrap k-muted">{{ transaction.date | frDate }}</td>
                      <td>{{ transaction.description ?? '—' }}</td>
                      <td class="k-nowrap">{{ transaction.category | label }}</td>
                      <td class="k-tertiary k-nowrap">
                        {{ transaction.source === 'manual' ? 'Saisie' : 'Automatique' }}
                      </td>
                      <td
                        class="k-num k-strong"
                        [style.color]="
                          transaction.type === 'income'
                            ? 'var(--k-success)'
                            : 'var(--k-danger)'
                        "
                      >
                        {{ transaction.type === 'income' ? '+' : '−' }}
                        {{ transaction.amount | amount }}
                      </td>
                    </tr>
                  }
                </tbody>
              </table>
            </div>
          }
        </article>
      </div>
    }
  `,
})
export class TreasuryPage {
  private readonly treasuryService = inject(TreasuryService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly categories = CATEGORIES;
  readonly treasury = signal<TreasurySnapshot | null>(null);
  readonly report = signal<ReportSnapshot | null>(null);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly formOpen = signal(false);

  readonly form = this.fb.nonNullable.group({
    type: ['income' as TransactionType, Validators.required],
    category: ['donation', Validators.required],
    amount: [0, [Validators.required, Validators.min(1)]],
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

    forkJoin({
      treasury: this.treasuryService.snapshot(organizationId),
      report: this.treasuryService.report(organizationId),
    }).subscribe({
      next: (result) => {
        this.treasury.set(result.treasury);
        this.report.set(result.report);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }

  submit(): void {
    const organizationId = this.session.organizationId();
    if (!organizationId || this.form.invalid || this.saving()) {
      this.form.markAllAsTouched();
      return;
    }
    this.saving.set(true);
    const raw = this.form.getRawValue();
    this.treasuryService
      .recordTransaction(organizationId, {
        type: raw.type,
        category: raw.category,
        amount: Number(raw.amount),
        description: raw.description.trim() || null,
      })
      .subscribe({
        next: () => {
          this.saving.set(false);
          this.formOpen.set(false);
          this.form.reset({ type: 'income', category: 'donation', amount: 0, description: '' });
          this.toast.success('Mouvement enregistré.');
          this.load();
        },
        error: (error: unknown) => {
          this.saving.set(false);
          this.toast.fromError(error);
        },
      });
  }
}
