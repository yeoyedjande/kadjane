import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

import { LabelPipe } from '../core/pipes/format.pipes';
import { AuthService } from '../core/services/auth.service';
import { NotificationService } from '../core/services/domain.services';
import { SessionService } from '../core/services/session.service';
import { ToastService } from '../core/services/toast.service';
import { StatusBadge, UserAvatar } from '../shared/ui.components';

interface NavEntry {
  path: string;
  label: string;
  icon: string;
  permission?: string;
  /** Rubriques prévues mais pas encore développées. */
  soon?: boolean;
}

const NAVIGATION: { section: string; entries: NavEntry[] }[] = [
  {
    section: 'Pilotage',
    entries: [
      { path: '/dashboard', label: 'Tableau de bord', icon: '◧' },
      {
        path: '/organizations',
        label: 'Organisations',
        icon: '⌂',
        permission: 'organization.view',
      },
      { path: '/members', label: 'Membres', icon: '☰', permission: 'member.view' },
    ],
  },
  {
    section: 'Tontines',
    entries: [
      { path: '/tontines', label: 'Tontines', icon: '◎', permission: 'tontine.view' },
      {
        path: '/contributions',
        label: 'Cotisations',
        icon: '≡',
        permission: 'contribution.view',
      },
      { path: '/draws', label: 'Tirages', icon: '✦', permission: 'draw.view' },
      {
        path: '/beneficiaries',
        label: 'Bénéficiaires',
        icon: '★',
        permission: 'payout.view',
      },
      { path: '/payouts', label: 'Versements', icon: '⇄', permission: 'payout.view' },
    ],
  },
  {
    section: 'Finances',
    entries: [
      { path: '/dues', label: 'Caisse', icon: '◈', permission: 'dues.view' },
      { path: '/treasury', label: 'Trésorerie', icon: '▤', permission: 'treasury.view' },
      { path: '/reminders', label: 'Relances', icon: '!', permission: 'reminder.view' },
    ],
  },
  {
    section: 'Administration',
    entries: [
      { path: '/notifications', label: 'Notifications', icon: '◔' },
      { path: '/audit', label: 'Audit', icon: '◈', permission: 'audit.view' },
      { path: '/settings', label: 'Paramètres', icon: '⚙', permission: 'organization.view' },
      { path: '/platform', label: 'Plateforme', icon: '⬢', permission: 'organization.edit' },
    ],
  },
  {
    section: 'Bientôt',
    entries: [
      { path: '/subscriptions', label: 'Abonnements', icon: '◇', soon: true },
      { path: '/website', label: 'Site Internet', icon: '◇', soon: true },
      { path: '/support', label: 'Support', icon: '◇', soon: true },
    ],
  },
];

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [
    CommonModule,
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    LabelPipe,
    StatusBadge,
    UserAvatar,
  ],
  templateUrl: './admin-layout.component.html',
  styleUrl: './admin-layout.component.scss',
})
export class AdminLayout {
  private readonly auth = inject(AuthService);
  private readonly notifications = inject(NotificationService);
  private readonly toast = inject(ToastService);

  readonly session = inject(SessionService);
  readonly user = this.auth.user;
  readonly collapsed = signal(false);
  readonly menuOpen = signal(false);
  readonly orgPickerOpen = signal(false);
  readonly unread = signal(0);

  readonly navigation = computed(() =>
    NAVIGATION.map((group) => ({
      section: group.section,
      entries: group.entries.filter(
        (entry) => !entry.permission || this.session.can(entry.permission),
      ),
    })).filter((group) => group.entries.length > 0),
  );

  readonly fullName = computed(() => {
    const user = this.user();
    return user ? `${user.firstName} ${user.lastName}` : '';
  });

  constructor() {
    this.refreshUnread();
  }

  refreshUnread(): void {
    this.notifications.unreadCount().subscribe({
      next: (count) => this.unread.set(count),
      error: () => this.unread.set(0),
    });
  }

  toggleSidebar(): void {
    this.collapsed.update((value) => !value);
  }

  selectOrganization(id: string): void {
    this.orgPickerOpen.set(false);
    if (id === this.session.organizationId()) {
      return;
    }
    this.session.select(id).subscribe({
      next: (organization) => {
        if (organization) {
          this.toast.info(`Organisation active : ${organization.name}`);
          // Les écrans lisent l'organisation active : un rechargement garantit
          // qu'aucune donnée de l'organisation précédente ne subsiste.
          location.reload();
        }
      },
      error: (error: unknown) => this.toast.fromError(error),
    });
  }

  logout(): void {
    this.session.reset();
    this.auth.logout();
  }
}
