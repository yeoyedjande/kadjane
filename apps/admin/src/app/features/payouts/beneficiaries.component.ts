import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';

import { Beneficiary } from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import {
  BeneficiaryService,
  TontineService,
} from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

interface Row {
  beneficiary: Beneficiary;
  tontineName: string;
  periodLabel: string;
}

@Component({
  selector: 'app-beneficiaries',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    FrDatePipe,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  template: `
    <k-page-header
      title="Bénéficiaires"
      subtitle="Les membres désignés pour recevoir la cagnotte. Ils continuent de cotiser."
    />

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && rows().length === 0"
      emptyTitle="Aucun bénéficiaire"
      emptyHint="Les bénéficiaires apparaissent après le premier tirage."
      (retry)="load()"
    />

    @if (rows().length > 0) {
      <article class="k-card">
        <div class="k-table-wrap">
          <table class="k-table">
            <thead>
              <tr>
                <th>Membre</th>
                <th>Tontine</th>
                <th>Période</th>
                <th class="k-num">Montant</th>
                <th>Désigné le</th>
                <th>Origine</th>
                <th>Statut</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              @for (row of rows(); track row.beneficiary.id) {
                <tr>
                  <td>
                    <div class="k-row">
                      <k-avatar [name]="row.beneficiary.memberName" />
                      <span class="k-strong">{{ row.beneficiary.memberName }}</span>
                    </div>
                  </td>
                  <td>{{ row.tontineName }}</td>
                  <td class="k-nowrap">{{ row.periodLabel }}</td>
                  <td class="k-num k-strong">{{ row.beneficiary.amount | money }}</td>
                  <td class="k-nowrap k-muted">{{ row.beneficiary.designatedAt | frDate }}</td>
                  <td class="k-nowrap">{{ row.beneficiary.source | label }}</td>
                  <td><k-badge [value]="row.beneficiary.status" /></td>
                  <td class="k-num">
                    <a
                      class="k-btn k-btn--ghost k-btn--sm"
                      [routerLink]="['/tontines', row.beneficiary.tontineId]"
                    >
                      Ouvrir
                    </a>
                  </td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </article>
    }
  `,
})
export class BeneficiariesPage {
  private readonly tontines = inject(TontineService);
  private readonly beneficiaries = inject(BeneficiaryService);
  readonly session = inject(SessionService);

  readonly rows = signal<Row[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

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

    this.tontines
      .list(organizationId)
      .pipe(
        switchMap((summaries) => {
          if (summaries.length === 0) {
            return of([] as Row[][]);
          }
          return forkJoin(
            summaries.map((summary) =>
              forkJoin({
                beneficiaries: this.beneficiaries.forTontine(summary.tontine.id),
                cycles: this.tontines.cycles(summary.tontine.id),
              }).pipe(
                switchMap((result) =>
                  of(
                    result.beneficiaries.map((beneficiary) => ({
                      beneficiary,
                      tontineName: summary.tontine.name,
                      periodLabel:
                        result.cycles.find((cycle) => cycle.id === beneficiary.cycleId)
                          ?.periodLabel ?? '—',
                    })),
                  ),
                ),
              ),
            ),
          );
        }),
      )
      .subscribe({
        next: (groups) => {
          this.rows.set(
            groups
              .flat()
              .sort((a, b) =>
                b.beneficiary.designatedAt.localeCompare(a.beneficiary.designatedAt),
              ),
          );
          this.loading.set(false);
        },
        error: (error: unknown) => {
          this.error.set(describeError(error));
          this.loading.set(false);
        },
      });
  }
}
