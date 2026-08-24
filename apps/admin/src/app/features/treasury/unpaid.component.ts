import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';

import { CampaignEntry } from '../../core/models/domain.models';
import { FrDatePipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { CampaignService } from '../../core/services/rbac-treasury.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  Pagination,
  SearchInput,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

const PAGE_SIZE = 50;

/** Impayés : membre, cotisation, dû, payé, reste, jours de retard.
 *
 *  Les lignes exemptées et annulées n'y figurent pas — elles ne sont pas des
 *  impayés, elles ne sont plus attendues.
 */
@Component({
  selector: 'app-unpaid',
  standalone: true,
  imports: [
    CommonModule,
    FrDatePipe,
    MoneyPipe,
    PageHeader,
    Pagination,
    SearchInput,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  templateUrl: './unpaid.component.html',
})
export class UnpaidPage {
  private readonly campaigns = inject(CampaignService);
  readonly session = inject(SessionService);

  readonly rows = signal<CampaignEntry[]>([]);
  readonly total = signal(0);
  readonly page = signal(0);
  readonly search = signal('');

  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly pageSize = PAGE_SIZE;

  readonly filtered = computed(() => {
    const needle = this.search().trim().toLowerCase();
    return this.rows().filter(
      (row) =>
        !needle ||
        row.memberName.toLowerCase().includes(needle) ||
        (row.campaignTitle ?? '').toLowerCase().includes(needle),
    );
  });

  /** Total dû sur la page courante : la somme des restes. */
  readonly outstanding = computed(() =>
    this.rows().reduce((sum, row) => sum + row.remainingAmount, 0),
  );

  readonly lateCount = computed(
    () => this.rows().filter((row) => row.status === 'late').length,
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
    this.campaigns
      .unpaid(organizationId, {
        limit: PAGE_SIZE,
        offset: this.page() * PAGE_SIZE,
      })
      .subscribe({
        next: (body) => {
          this.rows.set(body.items);
          this.total.set(body.total);
          this.loading.set(false);
        },
        error: (cause) => {
          this.error.set(describeError(cause));
          this.loading.set(false);
        },
      });
  }

  goToPage(page: number): void {
    this.page.set(page);
    this.load();
  }
}
