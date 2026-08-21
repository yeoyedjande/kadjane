import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';

import { AppNotification } from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe } from '../../core/pipes/format.pipes';
import { NotificationService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import { PageHeader, StateView, StatusBadge } from '../../shared/ui.components';

@Component({
  selector: 'app-notifications',
  standalone: true,
  imports: [CommonModule, FrDatePipe, LabelPipe, PageHeader, StateView, StatusBadge],
  template: `
    <k-page-header
      title="Notifications"
      subtitle="Créées par le serveur au fil des événements. L'envoi push reste à brancher."
    >
      <button type="button" class="k-btn k-btn--ghost" (click)="markAllRead()">
        Tout marquer comme lu
      </button>
    </k-page-header>

    <k-state
      [loading]="loading()"
      [error]="error()"
      [empty]="!loading() && !error() && items().length === 0"
      emptyTitle="Aucune notification"
      (retry)="load()"
    />

    @if (items().length > 0) {
      <article class="k-card">
        <div class="k-table-wrap">
          <table class="k-table">
            <thead>
              <tr>
                <th>Titre</th>
                <th>Type</th>
                <th>Message</th>
                <th>Date</th>
                <th>Statut</th>
              </tr>
            </thead>
            <tbody>
              @for (notification of items(); track notification.id) {
                <tr [class.is-unread]="!notification.readAt" (click)="open(notification)">
                  <td class="k-strong">{{ notification.title }}</td>
                  <td class="k-nowrap">{{ notification.type | label }}</td>
                  <td class="k-muted">{{ notification.body }}</td>
                  <td class="k-nowrap k-muted">{{ notification.createdAt | frDate: true }}</td>
                  <td>
                    <k-badge [value]="notification.readAt ? 'closed' : 'pending'" />
                  </td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </article>
    }
  `,
  styles: [
    `
      tr.is-unread td:first-child {
        box-shadow: inset 3px 0 0 var(--k-primary);
      }
      tbody tr {
        cursor: pointer;
      }
    `,
  ],
})
export class NotificationsPage {
  private readonly notifications = inject(NotificationService);
  private readonly toast = inject(ToastService);
  readonly session = inject(SessionService);

  readonly items = signal<AppNotification[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  constructor() {
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.error.set(null);
    this.notifications.list(this.session.organizationId()).subscribe({
      next: (items) => {
        this.items.set(items);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.error.set(describeError(error));
        this.loading.set(false);
      },
    });
  }

  open(notification: AppNotification): void {
    if (notification.readAt) {
      return;
    }
    this.notifications.markRead(notification.id).subscribe({
      next: () => this.load(),
      error: (error: unknown) => this.toast.fromError(error),
    });
  }

  markAllRead(): void {
    this.notifications.markAllRead().subscribe({
      next: (count) => {
        this.toast.success(`${count} notification(s) marquée(s) comme lue(s).`);
        this.load();
      },
      error: (error: unknown) => this.toast.fromError(error),
    });
  }
}
