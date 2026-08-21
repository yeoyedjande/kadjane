import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';

import {
  ContributionLine,
  ContributionTotals,
  TontineCycle,
  TontineSummary,
} from '../../core/models/domain.models';
import { AmountPipe, FrDatePipe, MoneyPipe } from '../../core/pipes/format.pipes';
import {
  ContributionService,
  TontineService,
} from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  SearchInput,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

@Component({
  selector: 'app-contributions',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    AmountPipe,
    FrDatePipe,
    MoneyPipe,
    PageHeader,
    SearchInput,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  template: `
    <k-page-header
      title="Cotisations"
      subtitle="Ce que chaque participant doit, ce qu'il a réglé."
    />

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && tontines().length === 0"
      emptyTitle="Aucune tontine active"
      emptyHint="Créez une tontine pour suivre les cotisations."
      (retry)="load()"
    />

    @if (tontines().length > 0) {
      <div class="k-stack">
        <article class="k-card">
          <div class="k-card__header">
            <div class="k-toolbar">
              <label class="k-field">
                <span class="k-label">Tontine</span>
                <select class="k-select" (change)="onTontineChange($any($event.target).value)">
                  @for (summary of tontines(); track summary.tontine.id) {
                    <option
                      [value]="summary.tontine.id"
                      [selected]="summary.tontine.id === tontineId()"
                    >
                      {{ summary.tontine.name }}
                    </option>
                  }
                </select>
              </label>

              <label class="k-field">
                <span class="k-label">Cycle</span>
                <select class="k-select" (change)="onCycleChange($any($event.target).value)">
                  @for (cycle of cycles(); track cycle.id) {
                    <option [value]="cycle.id" [selected]="cycle.id === cycleId()">
                      {{ cycle.periodLabel }}
                    </option>
                  }
                </select>
              </label>

              <label class="k-field">
                <span class="k-label">Statut</span>
                <select class="k-select" (change)="onStatusChange($any($event.target).value)">
                  <option value="">Tous</option>
                  <option value="paid">Payé</option>
                  <option value="partial">Partiel</option>
                  <option value="pending">En attente</option>
                  <option value="late">En retard</option>
                </select>
              </label>

              <k-search placeholder="Nom du membre…" (search)="onSearch($event)" />
            </div>
          </div>
        </article>

        @if (totals(); as totals) {
          <section class="k-grid k-grid--4">
            <k-stat label="Attendu" [value]="totals.expected | money" />
            <k-stat label="Collecté" [value]="totals.collected | money" [accent]="true" />
            <k-stat label="Restant" [value]="totals.remaining | money" />
            <k-stat
              label="Payés"
              [value]="totals.paid_count + ' / ' + totals.total"
              [hint]="totals.late_count + ' en retard'"
            />
          </section>
        }

        <article class="k-card">
          <div class="k-card__header">
            <h2 class="k-card__title">{{ currentCycleLabel() }}</h2>
            @if (tontineId()) {
              <a class="k-btn k-btn--sm k-btn--ghost" [routerLink]="['/tontines', tontineId()]">
                Ouvrir la tontine
              </a>
            }
          </div>

          @if (filtered().length === 0) {
            <div class="k-card__body"><p class="k-muted">Aucune cotisation.</p></div>
          } @else {
            <div class="k-table-wrap">
              <table class="k-table">
                <thead>
                  <tr>
                    <th>Membre</th>
                    <th>Période</th>
                    <th class="k-num">Attendu</th>
                    <th class="k-num">Payé</th>
                    <th class="k-num">Restant</th>
                    <th>Échéance</th>
                    <th>Statut</th>
                  </tr>
                </thead>
                <tbody>
                  @for (line of filtered(); track line.id) {
                    <tr>
                      <td>
                        <div class="k-row">
                          <k-avatar [name]="line.memberName" />
                          <div>
                            <div class="k-strong">{{ line.memberName }}</div>
                            @if (line.hasReceivedPot) {
                              <div class="k-tertiary" style="font-size: 12px">
                                Déjà bénéficiaire — cotise toujours
                              </div>
                            }
                          </div>
                        </div>
                      </td>
                      <td class="k-nowrap">{{ currentCycleLabel() }}</td>
                      <td class="k-num">{{ line.expectedAmount | amount }}</td>
                      <td class="k-num k-strong">{{ line.paidAmount | amount }}</td>
                      <td class="k-num">{{ line.remainingAmount | amount }}</td>
                      <td class="k-nowrap k-muted">{{ line.dueDate | frDate }}</td>
                      <td><k-badge [value]="line.status" /></td>
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
export class ContributionsPage {
  private readonly tontineService = inject(TontineService);
  private readonly contributionService = inject(ContributionService);
  readonly session = inject(SessionService);

  readonly tontines = signal<TontineSummary[]>([]);
  readonly cycles = signal<TontineCycle[]>([]);
  readonly lines = signal<ContributionLine[]>([]);
  readonly totals = signal<ContributionTotals | null>(null);

  readonly tontineId = signal<string | null>(null);
  readonly cycleId = signal<string | null>(null);
  readonly status = signal<string>('');
  readonly search = signal('');

  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly currentCycleLabel = computed(
    () => this.cycles().find((cycle) => cycle.id === this.cycleId())?.periodLabel ?? '—',
  );

  readonly filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    const status = this.status();
    return this.lines().filter(
      (line) =>
        (!term || line.memberName.toLowerCase().includes(term)) &&
        (!status || line.status === status),
    );
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

    this.tontineService
      .list(organizationId)
      .pipe(
        switchMap((summaries) => {
          this.tontines.set(summaries);
          const first = summaries[0]?.tontine.id ?? null;
          this.tontineId.set(first);
          return first
            ? forkJoin({ cycles: this.tontineService.cycles(first) })
            : of({ cycles: [] as TontineCycle[] });
        }),
      )
      .subscribe({
        next: ({ cycles }) => {
          this.cycles.set(cycles);
          const summary = this.tontines()[0];
          const current = summary?.currentCycle?.id ?? cycles[0]?.id ?? null;
          this.loading.set(false);
          if (current) {
            this.loadCycle(current);
          }
        },
        error: (error: unknown) => {
          this.error.set(describeError(error));
          this.loading.set(false);
        },
      });
  }

  onTontineChange(tontineId: string): void {
    this.tontineId.set(tontineId);
    this.tontineService.cycles(tontineId).subscribe({
      next: (cycles) => {
        this.cycles.set(cycles);
        const summary = this.tontines().find((item) => item.tontine.id === tontineId);
        const current = summary?.currentCycle?.id ?? cycles[0]?.id ?? null;
        if (current) {
          this.loadCycle(current);
        } else {
          this.lines.set([]);
          this.totals.set(null);
        }
      },
      error: (error: unknown) => this.error.set(describeError(error)),
    });
  }

  onCycleChange(cycleId: string): void {
    this.loadCycle(cycleId);
  }

  onStatusChange(status: string): void {
    this.status.set(status);
  }

  onSearch(value: string): void {
    this.search.set(value);
  }

  private loadCycle(cycleId: string): void {
    const tontineId = this.tontineId();
    if (!tontineId) {
      return;
    }
    this.cycleId.set(cycleId);
    this.contributionService.forCycle(tontineId, cycleId).subscribe({
      next: (result) => {
        this.lines.set(result.lines);
        this.totals.set(result.totals);
      },
      error: (error: unknown) => this.error.set(describeError(error)),
    });
  }
}
