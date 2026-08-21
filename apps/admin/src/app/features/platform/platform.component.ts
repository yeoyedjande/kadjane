import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { forkJoin, of, switchMap } from 'rxjs';

import { Organization } from '../../core/models/domain.models';
import { FrDatePipe, MoneyPipe } from '../../core/pipes/format.pipes';
import {
  MemberService,
  OrganizationService,
  TreasuryService,
} from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  StatCard,
  StateView,
  StatusBadge,
} from '../../shared/ui.components';

interface PlatformRow {
  organization: Organization;
  members: number;
  collected: number;
}

/** Drapeaux de plateforme prévus. Tant que `/app/config` n'existe pas côté
 *  backend, ils sont affichés en lecture seule : afficher un interrupteur qui
 *  ne fait rien serait pire que de l'annoncer. */
const FLAGS = [
  { key: 'cashbox_enabled', label: 'Caisse et trésorerie avancée' },
  { key: 'documents_enabled', label: 'Documents et archives' },
  { key: 'events_enabled', label: 'Événements' },
  { key: 'mobile_money_enabled', label: 'Mobile Money (paiement réel)' },
];

@Component({
  selector: 'app-platform',
  standalone: true,
  imports: [
    CommonModule,
    FrDatePipe,
    MoneyPipe,
    PageHeader,
    StatCard,
    StateView,
    StatusBadge,
  ],
  template: `
    <k-page-header
      title="Plateforme"
      subtitle="Vue transverse Kadjane. Le périmètre reste borné par ce que le serveur autorise."
    />

    <k-state [loading]="loading()" [error]="error()" (retry)="load()" />

    @if (!loading()) {
      <div class="k-stack">
        <section class="k-grid k-grid--3">
          <k-stat label="Organisations" [value]="rows().length.toString()" />
          <k-stat label="Membres" [value]="totalMembers().toString()" />
          <k-stat label="Collecté" [value]="totalCollected() | money" [accent]="true" />
        </section>

        <article class="k-card">
          <div class="k-card__header">
            <h2 class="k-card__title">Organisations</h2>
            @if (!session.isPlatformAdmin()) {
              <span class="k-tertiary" style="font-size: 12.5px">
                Vous voyez uniquement vos organisations : un super-administrateur
                plateforme verrait l'ensemble.
              </span>
            }
          </div>
          <div class="k-table-wrap">
            <table class="k-table">
              <thead>
                <tr>
                  <th>Organisation</th>
                  <th>Pays</th>
                  <th>Devise</th>
                  <th class="k-num">Membres</th>
                  <th class="k-num">Collecté</th>
                  <th>Statut</th>
                  <th>Créée le</th>
                </tr>
              </thead>
              <tbody>
                @for (row of rows(); track row.organization.id) {
                  <tr>
                    <td class="k-strong">{{ row.organization.name }}</td>
                    <td>{{ row.organization.country }}</td>
                    <td>{{ row.organization.currency }}</td>
                    <td class="k-num">{{ row.members }}</td>
                    <td class="k-num">{{ row.collected | money }}</td>
                    <td><k-badge [value]="row.organization.status" /></td>
                    <td class="k-nowrap k-muted">{{ row.organization.createdAt | frDate }}</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </article>

        <article class="k-card">
          <div class="k-card__header">
            <h2 class="k-card__title">Fonctionnalités de la plateforme</h2>
          </div>
          <div class="k-card__body">
            <p class="k-muted" style="margin-top: 0">
              Ces drapeaux attendent l'endpoint <code>/app/config</code> côté
              backend. Ils sont affichés en lecture seule tant qu'ils ne sont pas
              réellement pilotables — un interrupteur sans effet induirait en
              erreur.
            </p>
            <ul class="flags">
              @for (flag of flags; track flag.key) {
                <li>
                  <span>{{ flag.label }}</span>
                  <span class="flag__state">À venir</span>
                </li>
              }
            </ul>
          </div>
        </article>
      </div>
    }
  `,
  styles: [
    `
      .flags {
        margin: 0;
        padding: 0;
        list-style: none;
        border: 1px solid var(--k-outline);
        border-radius: var(--k-radius-sm);
        overflow: hidden;
      }
      .flags li {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 16px;
        padding: 12px 16px;
        border-bottom: 1px solid var(--k-outline);
      }
      .flags li:last-child {
        border-bottom: none;
      }
      .flag__state {
        padding: 3px 10px;
        border-radius: 999px;
        background: var(--k-surface-muted);
        color: var(--k-text-tertiary);
        font-size: 12px;
        font-weight: 650;
      }
      code {
        padding: 1px 5px;
        border-radius: 4px;
        background: var(--k-surface-muted);
        font-size: 12.5px;
      }
    `,
  ],
})
export class PlatformPage {
  private readonly organizations = inject(OrganizationService);
  private readonly members = inject(MemberService);
  private readonly treasury = inject(TreasuryService);
  readonly session = inject(SessionService);

  readonly flags = FLAGS;
  readonly rows = signal<PlatformRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly totalMembers = computed(() =>
    this.rows().reduce((sum, row) => sum + row.members, 0),
  );

  readonly totalCollected = computed(() =>
    this.rows().reduce((sum, row) => sum + row.collected, 0),
  );

  constructor() {
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.error.set(null);
    this.organizations
      .list()
      .pipe(
        switchMap((organizations) => {
          if (organizations.length === 0) {
            return of([] as PlatformRow[]);
          }
          return forkJoin(
            organizations.map((organization) =>
              forkJoin({
                members: this.members.list(organization.id, { pageSize: 1 }),
                report: this.treasury.report(organization.id),
              }).pipe(
                switchMap((result) =>
                  of<PlatformRow>({
                    organization,
                    members: result.members.total,
                    collected: result.report.totalCollected,
                  }),
                ),
              ),
            ),
          );
        }),
      )
      .subscribe({
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
