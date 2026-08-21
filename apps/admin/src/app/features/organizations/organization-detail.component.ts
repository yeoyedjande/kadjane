import { CommonModule } from '@angular/common';
import { Component, computed, inject, input, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin } from 'rxjs';

import {
  AuditLog,
  Member,
  Organization,
  TontineSummary,
} from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import {
  AuditService,
  MemberService,
  OrganizationService,
  TontineService,
} from '../../core/services/domain.services';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  StatCard,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

type Tab = 'overview' | 'members' | 'tontines' | 'activity' | 'settings';

@Component({
  selector: 'app-organization-detail',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    FrDatePipe,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    StatCard,
    StateView,
    StatusBadge,
    UserAvatar,
  ],
  templateUrl: './organization-detail.component.html',
})
export class OrganizationDetailPage {
  private readonly organizations = inject(OrganizationService);
  private readonly memberService = inject(MemberService);
  private readonly tontineService = inject(TontineService);
  private readonly auditService = inject(AuditService);

  /** Lié depuis l'URL par `withComponentInputBinding`. */
  readonly id = input.required<string>();

  readonly organization = signal<Organization | null>(null);
  readonly officers = signal<Member[]>([]);
  readonly members = signal<Member[]>([]);
  readonly membersTotal = signal(0);
  readonly tontines = signal<TontineSummary[]>([]);
  readonly activity = signal<AuditLog[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly tab = signal<Tab>('overview');

  readonly tabs: { key: Tab; label: string }[] = [
    { key: 'overview', label: 'Vue générale' },
    { key: 'members', label: 'Membres' },
    { key: 'tontines', label: 'Tontines' },
    { key: 'activity', label: 'Activité' },
    { key: 'settings', label: 'Paramètres' },
  ];

  readonly activeTontines = computed(
    () => this.tontines().filter((item) => item.tontine.status === 'active').length,
  );

  readonly lead = computed(() => this.officers()[0] ?? null);

  constructor() {
    queueMicrotask(() => this.load());
  }

  load(): void {
    const id = this.id();
    this.loading.set(true);
    this.error.set(null);

    forkJoin({
      organization: this.organizations.byId(id),
      officers: this.organizations.officers(id),
      members: this.memberService.list(id, { pageSize: 50 }),
      tontines: this.tontineService.list(id),
      activity: this.auditService.list(id, { limit: 20 }),
    }).subscribe({
      next: (result) => {
        this.organization.set(result.organization);
        this.officers.set(result.officers);
        this.members.set(result.members.items);
        this.membersTotal.set(result.members.total);
        this.tontines.set(result.tontines);
        this.activity.set(result.activity);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }
}
