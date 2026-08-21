import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Dashboard } from '../../core/models/domain.models';
import { AmountPipe, FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { OrganizationService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  BarChart,
  PageHeader,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    MoneyPipe,
    AmountPipe,
    FrDatePipe,
    LabelPipe,
    PageHeader,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
    BarChart,
  ],
  templateUrl: './dashboard.component.html',
})
export class DashboardPage {
  private readonly organizations = inject(OrganizationService);
  readonly session = inject(SessionService);

  readonly data = signal<Dashboard | null>(null);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly collectionRate = computed(() =>
    Math.round((this.data()?.collection_rate ?? 0) * 100),
  );

  readonly chartPoints = computed(() =>
    (this.data()?.trend ?? []).map((point) => ({
      label: new Intl.DateTimeFormat('fr-FR', {
        month: 'short',
        year: '2-digit',
      }).format(new Date(point.periodStart)),
      expected: point.expected,
      collected: point.collected,
    })),
  );

  /** Paiements récents extraits du journal : une seule requête suffit. */
  readonly recentPayments = computed(() =>
    (this.data()?.recentActivity ?? [])
      .filter((entry) => entry.action === 'contribution.confirmed')
      .slice(0, 5),
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
    this.organizations.dashboard(organizationId).subscribe({
      next: (dashboard) => {
        this.data.set(dashboard);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }
}
