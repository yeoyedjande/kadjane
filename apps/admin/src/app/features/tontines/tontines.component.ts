import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { TontineSummary } from '../../core/models/domain.models';
import { LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { TontineService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import { PageHeader, StateView, StatusBadge } from '../../shared/ui.components';

@Component({
  selector: 'app-tontines',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    StateView,
    StatusBadge,
  ],
  template: `
    <k-page-header title="Tontines" [subtitle]="subtitle()">
      @if (session.can('tontine.create')) {
        <a class="k-btn" routerLink="/tontines/new">Créer une tontine</a>
      }
    </k-page-header>

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && rows().length === 0"
      emptyTitle="Aucune tontine"
      emptyHint="Créez la première tontine de cette organisation."
      (retry)="load()"
    />

    @if (!loading() && rows().length > 0) {
      <article class="k-card">
        <div class="k-table-wrap">
          <table class="k-table">
            <thead>
              <tr>
                <th>Tontine</th>
                <th class="k-num">Cotisation</th>
                <th class="k-num">Cagnotte</th>
                <th class="k-num">Participants</th>
                <th>Mode</th>
                <th>Cycle actuel</th>
                <th>Collecte</th>
                <th>Statut</th>
              </tr>
            </thead>
            <tbody>
              @for (summary of rows(); track summary.tontine.id) {
                <tr>
                  <td>
                    <a [routerLink]="['/tontines', summary.tontine.id]" class="k-strong">
                      {{ summary.tontine.name }}
                    </a>
                    <div class="k-tertiary" style="font-size: 12px">
                      {{ summary.completedCycles }}/{{ summary.totalCycles }} cycles terminés
                    </div>
                  </td>
                  <td class="k-num">{{ summary.tontine.contributionAmount | money }}</td>
                  <td class="k-num k-strong">
                    {{ summary.tontine.contributionAmount * summary.participantCount | money }}
                  </td>
                  <td class="k-num">{{ summary.participantCount }}</td>
                  <td class="k-nowrap">{{ summary.tontine.allocationMode | label }}</td>
                  <td class="k-nowrap">{{ summary.currentCycle?.periodLabel ?? '—' }}</td>
                  <td style="min-width: 150px">
                    <div class="k-progress">
                      <div
                        class="k-progress__bar"
                        [style.width.%]="progress(summary)"
                      ></div>
                    </div>
                    <div class="k-tertiary" style="font-size: 12px; margin-top: 4px">
                      {{ summary.collectedCurrentCycle | money }} /
                      {{ summary.expectedCurrentCycle | money }}
                    </div>
                  </td>
                  <td><k-badge [value]="summary.tontine.status" /></td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </article>
    }
  `,
})
export class TontinesPage {
  private readonly tontines = inject(TontineService);
  readonly session = inject(SessionService);

  readonly rows = signal<TontineSummary[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  constructor() {
    this.load();
  }

  subtitle(): string {
    const count = this.rows().length;
    return count === 0 ? '' : `${count} tontine(s)`;
  }

  progress(summary: TontineSummary): number {
    if (summary.expectedCurrentCycle <= 0) {
      return 0;
    }
    return Math.min(
      100,
      Math.round((summary.collectedCurrentCycle / summary.expectedCurrentCycle) * 100),
    );
  }

  load(): void {
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      this.loading.set(false);
      return;
    }
    this.loading.set(true);
    this.error.set(null);
    this.tontines.list(organizationId).subscribe({
      next: (rows) => {
        this.rows.set(rows);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }
}
