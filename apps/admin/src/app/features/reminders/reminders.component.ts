import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ReminderTarget } from '../../core/models/domain.models';
import { FrDatePipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { ReminderService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

@Component({
  selector: 'app-reminders',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    FrDatePipe,
    MoneyPipe,
    PageHeader,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  template: `
    <k-page-header
      title="Relances"
      subtitle="Cotisations non réglées, classées par urgence. Un ancien bénéficiaire y figure : il cotise encore."
    />

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && targets().length === 0"
      emptyTitle="Personne à relancer"
      emptyHint="Toutes les cotisations attendues sont réglées."
      (retry)="load()"
    />

    @if (targets().length > 0) {
      <div class="k-stack">
        <section class="k-grid k-grid--3">
          <k-stat label="Membres à relancer" [value]="targets().length.toString()" />
          <k-stat label="Montant en attente" [value]="totalDue() | money" />
          <k-stat
            label="Retards escaladés"
            [value]="escalated().toString()"
            [hint]="escalated() > 0 ? 'Au-delà du délai de tolérance' : 'Aucun'"
          />
        </section>

        <article class="k-card">
          <div class="k-card__header">
            <h2 class="k-card__title">Cibles</h2>
            <span class="k-tertiary" style="font-size: 12.5px">
              L'envoi SMS / WhatsApp n'est pas encore branché : cette vue sert au suivi.
            </span>
          </div>
          <div class="k-table-wrap">
            <table class="k-table">
              <thead>
                <tr>
                  <th>Membre</th>
                  <th>Tontine</th>
                  <th>Période</th>
                  <th>Échéance</th>
                  <th class="k-num">Retard</th>
                  <th class="k-num">Montant dû</th>
                  <th>Niveau</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                @for (target of targets(); track target.contributionId ?? target.memberId + target.cycleId) {
                  <tr>
                    <td>
                      <div class="k-row">
                        <k-avatar [name]="target.memberName" />
                        <div>
                          <div class="k-strong">{{ target.memberName }}</div>
                          @if (target.hasReceivedPot) {
                            <div class="k-tertiary" style="font-size: 12px">
                              Déjà bénéficiaire — cotise toujours
                            </div>
                          }
                        </div>
                      </div>
                    </td>
                    <td>{{ target.tontineName }}</td>
                    <td class="k-nowrap">{{ target.periodLabel }}</td>
                    <td class="k-nowrap k-muted">{{ target.dueDate | frDate }}</td>
                    <td class="k-num">{{ target.daysLate }} j</td>
                    <td class="k-num k-strong">{{ target.amountDue | money }}</td>
                    <td><k-badge [value]="target.level" /></td>
                    <td class="k-num">
                      <a class="k-btn k-btn--ghost k-btn--sm" [routerLink]="['/tontines', target.tontineId]">
                        Ouvrir
                      </a>
                    </td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </article>
      </div>
    }
  `,
})
export class RemindersPage {
  private readonly reminders = inject(ReminderService);
  readonly session = inject(SessionService);

  readonly targets = signal<(ReminderTarget & { contributionId?: string })[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly totalDue = computed(() =>
    this.targets().reduce((sum, target) => sum + target.amountDue, 0),
  );

  readonly escalated = computed(
    () => this.targets().filter((target) => target.level === 'escalated').length,
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
    this.loading.set(true);
    this.error.set(null);
    this.reminders.targets(organizationId).subscribe({
      next: (targets) => {
        this.targets.set(targets);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }
}
