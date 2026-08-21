import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';

import { Payout } from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { PayoutService, TontineService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  ConfirmDialog,
  ConfirmRequest,
  PageHeader,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

interface Row {
  payout: Payout;
  tontineName: string;
}

@Component({
  selector: 'app-payouts',
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
    ConfirmDialog,
  ],
  template: `
    <k-page-header
      title="Versements"
      subtitle="Aucun versement n'est supprimé : une opération annulée reste tracée."
    />

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && rows().length === 0"
      emptyTitle="Aucun versement"
      emptyHint="Les versements se déclenchent depuis la fiche d'une tontine."
      (retry)="load()"
    />

    @if (rows().length > 0) {
      <article class="k-card">
        <div class="k-table-wrap">
          <table class="k-table">
            <thead>
              <tr>
                <th>Bénéficiaire</th>
                <th>Tontine</th>
                <th class="k-num">Montant</th>
                <th>Moyen</th>
                <th>Référence</th>
                <th>Date</th>
                <th>Statut</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              @for (row of rows(); track row.payout.id) {
                <tr>
                  <td>
                    <div class="k-row">
                      <k-avatar [name]="row.payout.memberName" />
                      <span class="k-strong">{{ row.payout.memberName }}</span>
                    </div>
                  </td>
                  <td>{{ row.tontineName }}</td>
                  <td class="k-num k-strong">{{ row.payout.amount | money }}</td>
                  <td class="k-nowrap">{{ row.payout.method | label }}</td>
                  <td class="k-tertiary">{{ row.payout.reference ?? '—' }}</td>
                  <td class="k-nowrap k-muted">{{ row.payout.sentAt | frDate }}</td>
                  <td>
                    <k-badge [value]="row.payout.status" />
                    @if (row.payout.failureReason) {
                      <div class="k-tertiary" style="font-size: 12px">
                        {{ row.payout.failureReason }}
                      </div>
                    }
                  </td>
                  <td class="k-num k-nowrap">
                    @if (session.can('payout.record')) {
                      @if (row.payout.status === 'pending' || row.payout.status === 'processing') {
                        <button
                          type="button"
                          class="k-btn k-btn--sm"
                          (click)="askConfirm(row.payout)"
                        >
                          Confirmer
                        </button>
                      }
                      @if (row.payout.status !== 'failed') {
                        <button
                          type="button"
                          class="k-btn k-btn--ghost k-btn--sm"
                          (click)="askFail(row.payout)"
                        >
                          Annuler
                        </button>
                      }
                    }
                    <a
                      class="k-btn k-btn--ghost k-btn--sm"
                      [routerLink]="['/tontines', row.payout.tontineId]"
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

    <k-confirm [open]="confirm()" (confirmed)="onConfirmed($event)" (cancelled)="onCancelled()" />
  `,
})
export class PayoutsPage {
  private readonly tontines = inject(TontineService);
  private readonly payouts = inject(PayoutService);
  private readonly toast = inject(ToastService);
  readonly session = inject(SessionService);

  readonly rows = signal<Row[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly confirm = signal<ConfirmRequest | null>(null);

  private pendingAction: ((reason: string) => void) | null = null;

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
              this.payouts.forTontine(summary.tontine.id).pipe(
                switchMap((payouts) =>
                  of(
                    payouts.map((payout) => ({
                      payout,
                      tontineName: summary.tontine.name,
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
              .sort((a, b) => b.payout.createdAt.localeCompare(a.payout.createdAt)),
          );
          this.loading.set(false);
        },
        error: (error: unknown) => {
          this.error.set(describeError(error));
          this.loading.set(false);
        },
      });
  }

  askConfirm(payout: Payout): void {
    this.pendingAction = () => {
      this.payouts.confirm(payout.id).subscribe({
        next: () => {
          this.toast.success(`Versement à ${payout.memberName} confirmé.`);
          this.load();
        },
        error: (error: unknown) => this.toast.fromError(error),
      });
    };
    this.confirm.set({
      title: 'Confirmer le versement',
      message: `${payout.memberName} sera marqué comme ayant reçu la cagnotte. Le cycle passera en « versé ».`,
      confirmLabel: 'Confirmer',
    });
  }

  askFail(payout: Payout): void {
    this.pendingAction = (reason) => {
      this.payouts.fail(payout.id, reason).subscribe({
        next: () => {
          this.toast.success('Versement marqué en échec — la trace est conservée.');
          this.load();
        },
        error: (error: unknown) => this.toast.fromError(error),
      });
    };
    this.confirm.set({
      title: 'Annuler le versement',
      message: `Le versement à ${payout.memberName} sera marqué en échec. Rien n'est supprimé : l'opération reste dans l'historique et dans l'audit.`,
      confirmLabel: 'Marquer en échec',
      danger: true,
      reasonLabel: 'Motif',
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
}
