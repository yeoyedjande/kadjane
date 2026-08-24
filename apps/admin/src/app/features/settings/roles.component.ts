import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import { Permission, Role } from '../../core/models/domain.models';
import { FrDatePipe } from '../../core/pipes/format.pipes';
import { RbacService } from '../../core/services/rbac-treasury.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  ConfirmDialog,
  ConfirmRequest,
  PageHeader,
  StateView,
  StatusBadge,
} from '../../shared/ui.components';

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

/** Rôles de l'organisation : créer, composer les droits, attribuer.
 *
 *  Un rôle système modifié ici devient une copie propre à l'organisation —
 *  le backend s'en charge. La console ne fait que cocher.
 */
@Component({
  selector: 'app-roles',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FrDatePipe,
    ConfirmDialog,
    PageHeader,
    StateView,
    StatusBadge,
  ],
  templateUrl: './roles.component.html',
})
export class RolesPage {
  private readonly rbac = inject(RbacService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly roles = signal<Role[]>([]);
  readonly catalog = signal<Permission[]>([]);
  readonly categories = signal<string[]>([]);
  readonly selectedId = signal<string | null>(null);
  /** État des cases cochées, avant enregistrement. */
  readonly draft = signal<Set<string>>(new Set());

  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly formOpen = signal(false);
  readonly confirm = signal<ConfirmRequest | null>(null);

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    description: [''],
  });

  readonly selected = computed(
    () => this.roles().find((role) => role.id === this.selectedId()) ?? null,
  );

  /** Permissions groupées par catégorie, dans l'ordre servi par l'API. */
  readonly grouped = computed(() => {
    const byCategory = new Map<string, Permission[]>();
    for (const permission of this.catalog()) {
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

  /** Vrai si les cases diffèrent de ce qui est enregistré. */
  readonly dirty = computed(() => {
    const role = this.selected();
    if (!role) {
      return false;
    }
    const draft = this.draft();
    return (
      draft.size !== role.permissions.length ||
      role.permissions.some((code) => !draft.has(code))
    );
  });

  readonly canEdit = computed(() => this.session.can('permission.assign'));

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

    this.rbac.catalog().subscribe({
      next: (body) => {
        this.catalog.set(body.permissions);
        this.categories.set(body.categories);
      },
      error: (cause) => this.error.set(describeError(cause)),
    });

    this.rbac.roles(organizationId).subscribe({
      next: (roles) => {
        this.roles.set(roles);
        const current = this.selectedId();
        const keep = roles.some((role) => role.id === current);
        this.select(keep ? (current as string) : (roles[0]?.id ?? null));
        this.loading.set(false);
      },
      error: (cause) => {
        this.error.set(describeError(cause));
        this.loading.set(false);
      },
    });
  }

  select(roleId: string | null): void {
    this.selectedId.set(roleId);
    const role = this.roles().find((item) => item.id === roleId);
    this.draft.set(new Set(role?.permissions ?? []));
  }

  toggle(code: string): void {
    if (!this.canEdit()) {
      return;
    }
    this.draft.update((current) => {
      const next = new Set(current);
      if (next.has(code)) {
        next.delete(code);
      } else {
        next.add(code);
      }
      return next;
    });
  }

  has(code: string): boolean {
    return this.draft().has(code);
  }

  /** Coche ou décoche une catégorie entière. */
  toggleCategory(category: string, checked: boolean): void {
    if (!this.canEdit()) {
      return;
    }
    const codes = this.catalog()
      .filter((permission) => permission.category === category)
      .map((permission) => permission.code);
    this.draft.update((current) => {
      const next = new Set(current);
      for (const code of codes) {
        if (checked) {
          next.add(code);
        } else {
          next.delete(code);
        }
      }
      return next;
    });
  }

  categoryState(category: string): 'all' | 'some' | 'none' {
    const codes = this.catalog().filter(
      (permission) => permission.category === category,
    );
    const checked = codes.filter((permission) => this.draft().has(permission.code));
    if (!checked.length) {
      return 'none';
    }
    return checked.length === codes.length ? 'all' : 'some';
  }

  reset(): void {
    this.select(this.selectedId());
  }

  /** §34 : confirmation avant toute modification de droits. */
  askSave(): void {
    const role = this.selected();
    if (!role || !this.dirty()) {
      return;
    }
    const draft = this.draft();
    const added = [...draft].filter((code) => !role.permissions.includes(code));
    const removed = role.permissions.filter((code) => !draft.has(code));

    this.confirm.set({
      title: `Modifier les droits de « ${role.name} »`,
      message:
        `${added.length} permission(s) ajoutée(s), ${removed.length} retirée(s). ` +
        (role.isSystem && !role.isCustomized
          ? "Ce rôle système sera copié au profit de votre association : les autres associations ne seront pas affectées."
          : `${role.memberCount} membre(s) portent ce rôle.`),
      confirmLabel: 'Enregistrer',
      danger: removed.length > 0,
    });
  }

  save(): void {
    this.confirm.set(null);
    const organizationId = this.session.organizationId();
    const role = this.selected();
    if (!organizationId || !role) {
      return;
    }
    this.saving.set(true);
    this.rbac
      .setPermissions(organizationId, role.id, [...this.draft()])
      .subscribe({
        next: (updated) => {
          // Le backend peut avoir retiré des droits que l'auteur ne possède
          // pas lui-même : on réaligne sur ce qu'il a réellement enregistré.
          this.roles.update((list) =>
            list.map((item) => (item.id === role.id ? updated : item)),
          );
          this.selectedId.set(updated.id);
          this.draft.set(new Set(updated.permissions));
          this.saving.set(false);
          this.toast.success('Droits mis à jour.');
        },
        error: (cause) => {
          this.saving.set(false);
          this.toast.error(describeError(cause));
        },
      });
  }

  openCreate(): void {
    this.form.reset({ name: '', description: '' });
    this.formOpen.set(true);
  }

  create(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }
    this.saving.set(true);
    const { name, description } = this.form.getRawValue();
    this.rbac
      .create(organizationId, {
        name,
        description,
        // Le rôle naît sans droits : on les coche ensuite, écran ouvert.
        permissions: [],
      })
      .subscribe({
        next: (role) => {
          this.roles.update((list) => [...list, role]);
          this.select(role.id);
          this.formOpen.set(false);
          this.saving.set(false);
          this.toast.success('Rôle créé. Cochez ses permissions.');
        },
        error: (cause) => {
          this.saving.set(false);
          this.toast.error(describeError(cause));
        },
      });
  }

  /** Duplique un rôle avec ses droits : le plus court chemin vers une variante. */
  duplicate(role: Role): void {
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }
    this.saving.set(true);
    this.rbac
      .create(organizationId, {
        name: `${role.name} (copie)`,
        description: role.description,
        permissions: role.permissions,
      })
      .subscribe({
        next: (created) => {
          this.roles.update((list) => [...list, created]);
          this.select(created.id);
          this.saving.set(false);
          this.toast.success('Rôle dupliqué.');
        },
        error: (cause) => {
          this.saving.set(false);
          this.toast.error(describeError(cause));
        },
      });
  }

  askDisable(role: Role): void {
    this.confirm.set({
      title: `Désactiver « ${role.name} »`,
      message:
        `${role.memberCount} membre(s) portent ce rôle et perdront leurs droits ` +
        'immédiatement. Le rôle reste en base et peut être réactivé.',
      confirmLabel: 'Désactiver',
      danger: true,
    });
    this.pendingDisable = role;
  }

  private pendingDisable: Role | null = null;

  onConfirmed(): void {
    const role = this.pendingDisable;
    this.pendingDisable = null;
    if (!role) {
      this.save();
      return;
    }
    const organizationId = this.session.organizationId();
    this.confirm.set(null);
    if (!organizationId) {
      return;
    }
    this.rbac
      .update(organizationId, role.id, { status: 'disabled' })
      .subscribe({
        next: (updated) => {
          this.roles.update((list) =>
            list.map((item) => (item.id === role.id ? updated : item)),
          );
          this.toast.success('Rôle désactivé.');
        },
        error: (cause) => this.toast.error(describeError(cause)),
      });
  }

  onCancelled(): void {
    this.pendingDisable = null;
    this.confirm.set(null);
  }

  label(category: string): string {
    return CATEGORY_LABELS[category] ?? category;
  }
}
