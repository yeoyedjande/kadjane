import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';

import { AuditLog } from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe, MoneyPipe } from '../../core/pipes/format.pipes';
import { AuditService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import {
  PageHeader,
  SearchInput,
  StateView,
  UserAvatar,
} from '../../shared/ui.components';

const ACTIONS = [
  'tontine.created',
  'tontine.status_changed',
  'contribution.recorded',
  'contribution.confirmed',
  'contribution.cancelled',
  'draw.completed',
  'draw.overridden',
  'draw.invalidated',
  'beneficiary.designated',
  'payout.recorded',
  'payout.confirmed',
  'member.created',
  'member.updated',
  'transaction.recorded',
];

@Component({
  selector: 'app-audit',
  standalone: true,
  imports: [
    CommonModule,
    FrDatePipe,
    LabelPipe,
    MoneyPipe,
    PageHeader,
    SearchInput,
    StateView,
    UserAvatar,
  ],
  templateUrl: './audit.component.html',
  styles: [
    `
      tr.is-selected {
        background: #f4fbf8;
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
      .meta {
        margin: 6px 0 0;
        padding: 0;
        list-style: none;
        border: 1px solid var(--k-outline);
        border-radius: var(--k-radius-sm);
        overflow: hidden;
      }
      .meta li {
        display: flex;
        justify-content: space-between;
        gap: 12px;
        padding: 8px 12px;
        border-bottom: 1px solid var(--k-outline);
        font-size: 13px;
      }
      .meta li:last-child {
        border-bottom: none;
      }
      .meta__key {
        color: var(--k-text-secondary);
      }
      .meta__value {
        font-weight: 600;
        word-break: break-all;
        text-align: right;
      }
    `,
  ],
})
export class AuditPage {
  private readonly audit = inject(AuditService);
  readonly session = inject(SessionService);

  readonly actions = ACTIONS;
  readonly entries = signal<AuditLog[]>([]);
  readonly selected = signal<AuditLog | null>(null);
  readonly action = signal('');
  readonly targetType = signal('');
  readonly search = signal('');
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  readonly types = computed(
    () =>
      [
        ...new Set(
          this.entries()
            .map((entry) => entry.targetType)
            .filter((value): value is string => Boolean(value)),
        ),
      ] as string[],
  );

  readonly filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    const type = this.targetType();
    return this.entries().filter(
      (entry) =>
        (!type || entry.targetType === type) &&
        (!term ||
          entry.description.toLowerCase().includes(term) ||
          entry.actorName.toLowerCase().includes(term)),
    );
  });

  constructor() {
    this.load();
  }

  onAction(action: string): void {
    this.action.set(action);
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
    this.audit
      .list(organizationId, { actions: this.action() || null, limit: 200 })
      .subscribe({
        next: (entries) => {
          this.entries.set(entries);
          this.selected.set(entries[0] ?? null);
          this.loading.set(false);
        },
        error: (error: unknown) => {
          this.error.set(describeError(error));
          this.loading.set(false);
        },
      });
  }

  metadataEntries(entry: AuditLog): { key: string; value: string }[] {
    return Object.entries(entry.metadata ?? {}).map(([key, value]) => ({
      key,
      value: typeof value === 'object' ? JSON.stringify(value) : String(value),
    }));
  }
}
