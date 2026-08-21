import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';

import { DrawSession, TontineSummary } from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe } from '../../core/pipes/format.pipes';
import { DrawService, TontineService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

interface DrawRow {
  draw: DrawSession;
  tontineName: string;
}

@Component({
  selector: 'app-draws',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    FrDatePipe,
    LabelPipe,
    PageHeader,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  template: `
    <k-page-header
      title="Tirages"
      subtitle="Le bénéficiaire est calculé et scellé par le serveur. Cette console ne peut pas le modifier."
    />

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && rows().length === 0"
      emptyTitle="Aucun tirage"
      emptyHint="Les tirages se lancent depuis la fiche d'une tontine."
      (retry)="load()"
    />

    @if (rows().length > 0) {
      <div class="k-grid" style="grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr)">
        <article class="k-card">
          <div class="k-card__header"><h2 class="k-card__title">Historique</h2></div>
          <div class="k-table-wrap">
            <table class="k-table">
              <thead>
                <tr>
                  <th>Tontine</th>
                  <th>Période</th>
                  <th>Date</th>
                  <th>Bénéficiaire</th>
                  <th class="k-num">Éligibles</th>
                  <th>Forçage</th>
                  <th>Statut</th>
                </tr>
              </thead>
              <tbody>
                @for (row of rows(); track row.draw.id) {
                  <tr
                    [class.is-selected]="row.draw.id === selected()?.id"
                    (click)="selected.set(row.draw)"
                    style="cursor: pointer"
                  >
                    <td class="k-strong">{{ row.tontineName }}</td>
                    <td class="k-nowrap">{{ row.draw.periodLabel }}</td>
                    <td class="k-nowrap k-muted">{{ row.draw.executedAt | frDate }}</td>
                    <td>{{ row.draw.winnerName ?? '—' }}</td>
                    <td class="k-num">{{ row.draw.participants.length }}</td>
                    <td>
                      @if (row.draw.overrideUsed) {
                        <span class="tag">Forcé</span>
                      } @else {
                        <span class="k-tertiary">—</span>
                      }
                    </td>
                    <td><k-badge [value]="row.draw.status" /></td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </article>

        <article class="k-card">
          <div class="k-card__header"><h2 class="k-card__title">Détail du tirage</h2></div>
          @if (selected(); as draw) {
            <div class="k-card__body k-stack">
              <div class="winner">
                <k-avatar [name]="draw.winnerName ?? '?'" [size]="44" />
                <div>
                  <p class="k-strong" style="margin: 0; font-size: 16px">
                    {{ draw.winnerName ?? 'Aucun gagnant' }}
                  </p>
                  <p class="k-muted" style="margin: 2px 0 0">{{ draw.periodLabel }}</p>
                </div>
              </div>

              <dl class="facts">
                <div><dt>Identifiant</dt><dd class="k-tertiary">{{ draw.id }}</dd></div>
                <div><dt>Date et heure</dt><dd>{{ draw.executedAt | frDate: true }}</dd></div>
                <div><dt>Type</dt><dd>{{ draw.drawType | label }}</dd></div>
                <div><dt>Preuve</dt><dd>{{ draw.proofReference }}</dd></div>
                <div><dt>Source aléatoire</dt><dd>{{ draw.randomSourceLabel }}</dd></div>
                <div><dt>Statut</dt><dd><k-badge [value]="draw.status" /></dd></div>
                @if (draw.overrideUsed) {
                  <div>
                    <dt>Forçage</dt>
                    <dd class="k-strong" style="color: var(--k-warning)">Oui</dd>
                  </div>
                  <div>
                    <dt>Justification</dt>
                    <dd>{{ draw.overrideReason }}</dd>
                  </div>
                }
              </dl>

              <div>
                <p class="k-label">
                  Participants éligibles au moment du tirage ({{ draw.participants.length }})
                </p>
                <ul class="chips">
                  @for (participant of draw.participants; track participant.participantId) {
                    <li
                      class="chip"
                      [class.chip--winner]="
                        participant.participantId === draw.winnerParticipantId
                      "
                    >
                      {{ participant.displayName }}
                    </li>
                  }
                </ul>
              </div>

              <a class="k-btn k-btn--ghost" [routerLink]="['/tontines', draw.tontineId]">
                Ouvrir la tontine
              </a>
            </div>
          } @else {
            <div class="k-card__body">
              <p class="k-muted">Sélectionnez un tirage pour voir son détail.</p>
            </div>
          }
        </article>
      </div>
    }
  `,
  styles: [
    `
      .tag {
        display: inline-block;
        padding: 3px 10px;
        border-radius: 999px;
        background: var(--k-gold-container);
        color: #8a6011;
        font-size: 12px;
        font-weight: 650;
      }
      tr.is-selected {
        background: #f4fbf8;
      }
      .winner {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 14px;
        border-radius: var(--k-radius);
        background: var(--k-primary-container);
      }
      .facts {
        display: grid;
        gap: 8px;
        margin: 0;
      }
      .facts > div {
        display: flex;
        justify-content: space-between;
        gap: 14px;
        padding-bottom: 8px;
        border-bottom: 1px solid var(--k-outline);
      }
      .facts dt {
        color: var(--k-text-secondary);
        font-size: 13px;
      }
      .facts dd {
        margin: 0;
        font-weight: 600;
        text-align: right;
        word-break: break-all;
      }
      .chips {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
        margin: 8px 0 0;
        padding: 0;
        list-style: none;
      }
      .chip {
        padding: 4px 10px;
        border: 1px solid var(--k-outline);
        border-radius: 999px;
        font-size: 12.5px;
      }
      .chip--winner {
        border-color: var(--k-primary);
        background: var(--k-primary);
        color: #fff;
        font-weight: 650;
      }
    `,
  ],
})
export class DrawsPage {
  private readonly tontines = inject(TontineService);
  private readonly draws = inject(DrawService);
  readonly session = inject(SessionService);

  readonly rows = signal<DrawRow[]>([]);
  readonly selected = signal<DrawSession | null>(null);
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
        switchMap((summaries: TontineSummary[]) => {
          if (summaries.length === 0) {
            return of([] as DrawRow[][]);
          }
          return forkJoin(
            summaries.map((summary) =>
              this.draws.history(summary.tontine.id).pipe(
                switchMap((sessions) =>
                  of(
                    sessions.map((draw) => ({
                      draw,
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
          const rows = groups
            .flat()
            .sort((a, b) =>
              (b.draw.executedAt ?? '').localeCompare(a.draw.executedAt ?? ''),
            );
          this.rows.set(rows);
          this.selected.set(rows[0]?.draw ?? null);
          this.loading.set(false);
        },
        error: (error: unknown) => {
          this.error.set(describeError(error));
          this.loading.set(false);
        },
      });
  }
}
