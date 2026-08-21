import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';

import { Organization, TontineSummary } from '../../core/models/domain.models';
import { FrDatePipe } from '../../core/pipes/format.pipes';
import {
  MemberService,
  OrganizationService,
  TontineService,
} from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  ConfirmDialog,
  ConfirmRequest,
  PageHeader,
  StateView,
  StatusBadge,
} from '../../shared/ui.components';

interface OrganizationRow {
  organization: Organization;
  members: number;
  tontines: number;
}

@Component({
  selector: 'app-organizations',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    FrDatePipe,
    PageHeader,
    StateView,
    StatusBadge,
    ConfirmDialog,
  ],
  template: `
    <k-page-header
      title="Organisations"
      subtitle="Les organisations auxquelles vous appartenez. Le serveur ne renvoie jamais celles des autres."
    />

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && rows().length === 0"
      emptyTitle="Aucune organisation"
      (retry)="load()"
    />

    @if (!loading() && rows().length > 0) {
      <article class="k-card">
        <div class="k-table-wrap">
          <table class="k-table">
            <thead>
              <tr>
                <th>Organisation</th>
                <th class="k-num">Membres</th>
                <th class="k-num">Tontines</th>
                <th>Devise</th>
                <th>Statut</th>
                <th>Créée le</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              @for (row of rows(); track row.organization.id) {
                <tr>
                  <td>
                    <div class="k-strong">{{ row.organization.name }}</div>
                    <div class="k-tertiary" style="font-size: 12px">
                      {{ row.organization.country }} · {{ row.organization.slug }}
                    </div>
                  </td>
                  <td class="k-num">{{ row.members }}</td>
                  <td class="k-num">{{ row.tontines }}</td>
                  <td>{{ row.organization.currency }}</td>
                  <td><k-badge [value]="row.organization.status" /></td>
                  <td class="k-nowrap k-muted">{{ row.organization.createdAt | frDate }}</td>
                  <td class="k-num k-nowrap">
                    <a
                      class="k-btn k-btn--ghost k-btn--sm"
                      [routerLink]="['/organizations', row.organization.id]"
                    >
                      Consulter
                    </a>
                    @if (session.can('organization.edit')) {
                      <button
                        type="button"
                        class="k-btn k-btn--ghost k-btn--sm"
                        (click)="askToggle(row.organization)"
                      >
                        {{ row.organization.status === 'active' ? 'Suspendre' : 'Réactiver' }}
                      </button>
                    }
                  </td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </article>
    }

    <k-confirm [open]="confirm()" (confirmed)="applyToggle()" (cancelled)="confirm.set(null)" />
  `,
})
export class OrganizationsPage {
  private readonly organizations = inject(OrganizationService);
  private readonly members = inject(MemberService);
  private readonly tontines = inject(TontineService);
  private readonly toast = inject(ToastService);
  readonly session = inject(SessionService);

  readonly rows = signal<OrganizationRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly confirm = signal<ConfirmRequest | null>(null);

  private target: Organization | null = null;

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
            return of([] as OrganizationRow[]);
          }
          return forkJoin(
            organizations.map((organization) =>
              forkJoin({
                members: this.members.list(organization.id, { pageSize: 1 }),
                tontines: this.tontines.list(organization.id),
              }).pipe(
                switchMap((result) =>
                  of<OrganizationRow>({
                    organization,
                    members: result.members.total,
                    tontines: (result.tontines as TontineSummary[]).length,
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

  askToggle(organization: Organization): void {
    this.target = organization;
    const suspending = organization.status === 'active';
    this.confirm.set({
      title: suspending ? "Suspendre l'organisation" : "Réactiver l'organisation",
      message: suspending
        ? `« ${organization.name} » sera suspendue. Ses membres perdront l'accès aux opérations courantes.`
        : `« ${organization.name} » redeviendra active.`,
      confirmLabel: suspending ? 'Suspendre' : 'Réactiver',
      danger: suspending,
    });
  }

  applyToggle(): void {
    const organization = this.target;
    this.confirm.set(null);
    this.target = null;
    if (!organization) {
      return;
    }
    const next = organization.status === 'active' ? 'suspended' : 'active';
    this.organizations.setStatus(organization.id, next).subscribe({
      next: (updated) => {
        this.session.replace(updated);
        this.toast.success(
          next === 'suspended' ? 'Organisation suspendue.' : 'Organisation réactivée.',
        );
        this.load();
      },
      error: (error: unknown) => this.toast.fromError(error),
    });
  }
}
