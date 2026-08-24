import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';

import { Permission, Role } from '../../core/models/domain.models';
import { RbacService } from '../../core/services/rbac-treasury.services';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';
import { PageHeader, SearchInput, StateView } from '../../shared/ui.components';

const CATEGORY_LABELS: Record<string, string> = {
  organization: 'Organisation',
  members: 'Membres',
  tontines: 'Tontines',
  contributions: 'Cotisations',
  payments: 'Paiements',
  cashbox: 'Caisse et trésorerie',
  draws: 'Tirages',
  payouts: 'Versements',
  dues: 'Cotisations de caisse',
  reminders: 'Relances',
  reports: 'Rapports',
  audit: 'Audit',
  administration: 'Administration',
};

/** Catalogue des permissions, croisé avec les rôles de l'organisation.
 *
 *  Écran de **lecture** : le catalogue décrit ce que le backend sait protéger,
 *  il ne s'administre pas. Les cases se cochent dans la fiche d'un rôle.
 */
@Component({
  selector: 'app-permissions',
  standalone: true,
  imports: [CommonModule, PageHeader, SearchInput, StateView],
  templateUrl: './permissions.component.html',
})
export class PermissionsPage {
  private readonly rbac = inject(RbacService);
  readonly session = inject(SessionService);

  readonly catalog = signal<Permission[]>([]);
  readonly categories = signal<string[]>([]);
  readonly roles = signal<Role[]>([]);
  readonly search = signal('');

  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  /** Colonnes du tableau : les rôles, du plus faible au plus fort. */
  readonly columns = computed(() =>
    [...this.roles()]
      .filter((role) => role.status === 'active')
      .reverse(),
  );

  readonly grouped = computed(() => {
    const needle = this.search().trim().toLowerCase();
    const matching = this.catalog().filter(
      (permission) =>
        !needle ||
        permission.code.toLowerCase().includes(needle) ||
        permission.name.toLowerCase().includes(needle) ||
        permission.description.toLowerCase().includes(needle),
    );

    const byCategory = new Map<string, Permission[]>();
    for (const permission of matching) {
      const bucket = byCategory.get(permission.category) ?? [];
      bucket.push(permission);
      byCategory.set(permission.category, bucket);
    }
    return this.categories()
      .filter((category) => byCategory.has(category))
      .map((category) => ({
        code: category,
        label: CATEGORY_LABELS[category] ?? category,
        permissions: byCategory.get(category) ?? [],
      }));
  });

  readonly total = computed(() => this.catalog().length);

  constructor() {
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.error.set(null);

    this.rbac.catalog().subscribe({
      next: (body) => {
        this.catalog.set(body.permissions);
        this.categories.set(body.categories);
        this.loading.set(false);
      },
      error: (cause) => {
        this.error.set(describeError(cause));
        this.loading.set(false);
      },
    });

    const organizationId = this.session.organizationId();
    if (organizationId) {
      this.rbac.roles(organizationId).subscribe({
        next: (roles) => this.roles.set(roles),
        error: () => {
          // Le catalogue reste lisible sans la matrice : l'écran dégrade au
          // lieu de disparaître.
        },
      });
    }
  }

  granted(role: Role, code: string): boolean {
    return role.permissions.includes(code);
  }
}
