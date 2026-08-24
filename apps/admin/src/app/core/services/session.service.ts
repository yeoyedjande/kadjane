import { Injectable, computed, inject, signal } from '@angular/core';
import { Observable, map, of, switchMap, tap } from 'rxjs';

import { Member, MyPermissions, Organization, OrgRole } from '../models/domain.models';
import { ApiClient } from './api-client.service';
import { AuthService } from './auth.service';

const ACTIVE_ORG_KEY = 'kadjane.admin.activeOrganization';

/** Repli de **lecture seule**, le temps que `/me/permissions` réponde.
 *
 *  Il ne contient que des droits de consultation. Un repli permissif — l'ancien
 *  `ALL_PERMISSIONS` — affichait tous les boutons d'administration quand l'API
 *  tardait : le backend refusait bien les appels, mais l'interface promettait
 *  des actions impossibles.
 *
 *  L'autorisation réelle reste côté FastAPI : masquer un bouton n'a jamais
 *  protégé une API.
 */
const READ_ONLY_FALLBACK = [
  'organization.view',
  'member.view',
  'tontine.view',
  'contribution.view',
  'draw.view',
  'payout.view',
  'reminder.view',
];

@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly api = inject(ApiClient);
  private readonly auth = inject(AuthService);

  private readonly organizationList = signal<Organization[]>([]);
  private readonly activeId = signal<string | null>(null);
  private readonly currentMembership = signal<Member | null>(null);
  private readonly grantedPermissions = signal<string[]>([]);
  private readonly roleLabel = signal<string | null>(null);
  private readonly loadingState = signal(false);

  readonly organizations = this.organizationList.asReadonly();
  readonly membership = this.currentMembership.asReadonly();
  readonly loading = this.loadingState.asReadonly();

  readonly organization = computed(() => {
    const id = this.activeId();
    return this.organizationList().find((item) => item.id === id) ?? null;
  });

  readonly organizationId = computed(() => this.organization()?.id ?? null);
  readonly currency = computed(() => this.organization()?.currency ?? 'XOF');
  readonly role = computed<OrgRole | null>(() => this.currentMembership()?.role ?? null);

  /** Super administrateur plateforme : accès transverse. */
  readonly isPlatformAdmin = computed(() => this.role() === 'super_admin');

  /** Droits réels du membre, servis par `/me/permissions`.
   *
   *  Lus par membre et non par rôle : un rôle sur mesure n'a pas d'entrée dans
   *  une matrice indexée par nom de rôle.
   */
  readonly permissions = computed<string[]>(() => {
    const granted = this.grantedPermissions();
    if (granted.length) {
      return granted;
    }
    return this.role() ? READ_ONLY_FALLBACK : [];
  });

  /** Nom affichable du rôle, y compris pour un rôle sur mesure. */
  readonly roleName = computed(() => this.roleLabel());

  can(permission: string): boolean {
    return this.permissions().includes(permission);
  }

  canAny(...permissions: string[]): boolean {
    return permissions.some((permission) => this.can(permission));
  }

  /** Charge les organisations de l'utilisateur et sélectionne l'active. */
  load(): Observable<Organization | null> {
    this.loadingState.set(true);
    return this.api.get<Organization[]>('/organizations').pipe(
      tap((organizations) => this.organizationList.set(organizations)),
      map((organizations) => {
        const stored = localStorage.getItem(ACTIVE_ORG_KEY);
        const valid = organizations.some((item) => item.id === stored);
        const selected = valid ? stored : (organizations[0]?.id ?? null);
        this.activeId.set(selected);
        return organizations.find((item) => item.id === selected) ?? null;
      }),
      switchMap((organization) =>
        organization ? this.loadContext(organization) : of(null),
      ),
      tap(() => this.loadingState.set(false)),
    );
  }

  select(organizationId: string): Observable<Organization | null> {
    const organization = this.organizationList().find(
      (item) => item.id === organizationId,
    );
    if (!organization) {
      return of(null);
    }
    this.activeId.set(organizationId);
    localStorage.setItem(ACTIVE_ORG_KEY, organizationId);
    return this.loadContext(organization);
  }

  /** Rafraîchit une organisation modifiée sans recharger toute la liste. */
  replace(organization: Organization): void {
    this.organizationList.update((list) =>
      list.map((item) => (item.id === organization.id ? organization : item)),
    );
  }

  reset(): void {
    this.organizationList.set([]);
    this.activeId.set(null);
    this.currentMembership.set(null);
    this.grantedPermissions.set([]);
    this.roleLabel.set(null);
  }

  private loadContext(organization: Organization): Observable<Organization | null> {
    localStorage.setItem(ACTIVE_ORG_KEY, organization.id);
    const userId = this.auth.user()?.id;
    return this.api
      .get<Member>(`/organizations/${organization.id}/membership`, { userId })
      .pipe(
        tap((membership) => this.currentMembership.set(membership)),
        switchMap(() =>
          this.api.get<MyPermissions[]>('/me/permissions', {
            organizationId: organization.id,
          }),
        ),
        tap((entries) => {
          const mine = entries.find(
            (entry) => entry.organizationId === organization.id,
          );
          this.grantedPermissions.set(mine?.permissions ?? []);
          this.roleLabel.set(mine?.roleName ?? null);
        }),
        map(() => organization),
      );
  }
}
