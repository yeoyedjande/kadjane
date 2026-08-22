import { Routes } from '@angular/router';

import { authGuard, guestGuard } from './core/guards/auth.guard';
import { permissionGuard } from './core/guards/permission.guard';

/** Chaque écran est chargé à la demande : l'ouverture du back-office ne
 *  télécharge que la coquille et le tableau de bord. */
export const routes: Routes = [
  {
    path: 'login',
    canActivate: [guestGuard],
    loadComponent: () =>
      import('./features/auth/login.component').then((m) => m.LoginPage),
  },
  {
    path: '',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./layout/admin-layout.component').then((m) => m.AdminLayout),
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      {
        path: 'dashboard',
        loadComponent: () =>
          import('./features/dashboard/dashboard.component').then(
            (m) => m.DashboardPage,
          ),
      },
      {
        path: 'organizations',
        canActivate: [permissionGuard('organization.view')],
        loadComponent: () =>
          import('./features/organizations/organizations.component').then(
            (m) => m.OrganizationsPage,
          ),
      },
      {
        path: 'organizations/:id',
        canActivate: [permissionGuard('organization.view')],
        loadComponent: () =>
          import('./features/organizations/organization-detail.component').then(
            (m) => m.OrganizationDetailPage,
          ),
      },
      {
        path: 'members',
        canActivate: [permissionGuard('member.view')],
        loadComponent: () =>
          import('./features/members/members.component').then((m) => m.MembersPage),
      },
      {
        path: 'tontines',
        canActivate: [permissionGuard('tontine.view')],
        loadComponent: () =>
          import('./features/tontines/tontines.component').then((m) => m.TontinesPage),
      },
      {
        path: 'tontines/new',
        canActivate: [permissionGuard('tontine.create')],
        loadComponent: () =>
          import('./features/tontines/tontine-wizard.component').then(
            (m) => m.TontineWizardPage,
          ),
      },
      {
        path: 'tontines/:id',
        canActivate: [permissionGuard('tontine.view')],
        loadComponent: () =>
          import('./features/tontines/tontine-detail.component').then(
            (m) => m.TontineDetailPage,
          ),
      },
      {
        path: 'contributions',
        canActivate: [permissionGuard('contribution.view')],
        loadComponent: () =>
          import('./features/contributions/contributions.component').then(
            (m) => m.ContributionsPage,
          ),
      },
      {
        path: 'draws',
        canActivate: [permissionGuard('draw.view')],
        loadComponent: () =>
          import('./features/draws/draws.component').then((m) => m.DrawsPage),
      },
      {
        path: 'beneficiaries',
        canActivate: [permissionGuard('payout.view')],
        loadComponent: () =>
          import('./features/payouts/beneficiaries.component').then(
            (m) => m.BeneficiariesPage,
          ),
      },
      {
        path: 'payouts',
        canActivate: [permissionGuard('payout.view')],
        loadComponent: () =>
          import('./features/payouts/payouts.component').then((m) => m.PayoutsPage),
      },
      {
        path: 'dues',
        canActivate: [permissionGuard('dues.view')],
        loadComponent: () =>
          import('./features/dues/dues.component').then((m) => m.DuesPage),
      },
      {
        path: 'treasury',
        canActivate: [permissionGuard('treasury.view')],
        loadComponent: () =>
          import('./features/treasury/treasury.component').then((m) => m.TreasuryPage),
      },
      {
        path: 'reminders',
        canActivate: [permissionGuard('reminder.view')],
        loadComponent: () =>
          import('./features/reminders/reminders.component').then(
            (m) => m.RemindersPage,
          ),
      },
      {
        path: 'notifications',
        loadComponent: () =>
          import('./features/notifications/notifications.component').then(
            (m) => m.NotificationsPage,
          ),
      },
      {
        path: 'audit',
        canActivate: [permissionGuard('audit.view')],
        loadComponent: () =>
          import('./features/audit/audit.component').then((m) => m.AuditPage),
      },
      {
        path: 'settings',
        canActivate: [permissionGuard('organization.view')],
        loadComponent: () =>
          import('./features/settings/settings.component').then((m) => m.SettingsPage),
      },
      {
        path: 'platform',
        canActivate: [permissionGuard('organization.edit')],
        loadComponent: () =>
          import('./features/platform/platform.component').then((m) => m.PlatformPage),
      },
    ],
  },
  { path: '**', redirectTo: '' },
];
