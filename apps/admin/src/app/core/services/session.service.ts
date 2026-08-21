import { Injectable, computed, inject, signal } from '@angular/core';
import { Observable, map, of, switchMap, tap } from 'rxjs';

import { Member, Organization, OrgRole } from '../models/domain.models';
import { ApiClient } from './api-client.service';
import { AuthService } from './auth.service';

const ACTIVE_ORG_KEY = 'kadjane.admin.activeOrganization';

/** Matrice des droits par défaut — **copie d'affichage** de celle du backend.
 *
 *  Elle sert uniquement à masquer ce qui n'est pas permis. L'autorisation
 *  réelle reste côté FastAPI : masquer un bouton n'a jamais protégé une API.
 *  Elle est remplacée par la matrice servie par `/organizations/{id}/roles`
 *  dès qu'elle arrive.
 */
const MEMBER_PERMISSIONS = [
  'organization.view',
  'member.view',
  'tontine.view',
  'contribution.view',
  'draw.view',
  'payout.view',
  'reminder.view',
];

const FALLBACK_MATRIX: Record<OrgRole, string[]> = {
  member: MEMBER_PERMISSIONS,
  auditor: [...MEMBER_PERMISSIONS, 'treasury.view', 'report.view', 'audit.view'],
  treasurer: [
    ...MEMBER_PERMISSIONS,
    'treasury.view',
    'report.view',
    'audit.view',
    'contribution.record',
    'contribution.confirm',
    'contribution.cancel',
    'payout.record',
    'treasury.manage',
    'reminder.send',
  ],
  president: [
    ...MEMBER_PERMISSIONS,
    'treasury.view',
    'report.view',
    'audit.view',
    'tontine.validate',
    'draw.run',
    'member.invite',
    'reminder.send',
  ],
  admin: [],
  super_admin: [],
};

@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly api = inject(ApiClient);
  private readonly auth = inject(AuthService);

  private readonly organizationList = signal<Organization[]>([]);
  private readonly activeId = signal<string | null>(null);
  private readonly currentMembership = signal<Member | null>(null);
  private readonly permissionMatrix = signal<Record<string, string[]>>({});
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

  readonly permissions = computed<string[]>(() => {
    const role = this.role();
    if (!role) {
      return [];
    }
    const served = this.permissionMatrix()[role];
    if (served?.length) {
      return served;
    }
    const fallback = FALLBACK_MATRIX[role];
    return fallback.length ? fallback : ALL_PERMISSIONS;
  });

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
    this.permissionMatrix.set({});
  }

  private loadContext(organization: Organization): Observable<Organization | null> {
    localStorage.setItem(ACTIVE_ORG_KEY, organization.id);
    const userId = this.auth.user()?.id;
    return this.api
      .get<Member>(`/organizations/${organization.id}/membership`, { userId })
      .pipe(
        tap((membership) => this.currentMembership.set(membership)),
        switchMap(() =>
          this.api.get<{ role: OrgRole; permissions: string[] }[]>(
            `/organizations/${organization.id}/roles`,
          ),
        ),
        tap((definitions) => {
          const matrix: Record<string, string[]> = {};
          for (const definition of definitions) {
            matrix[definition.role] = definition.permissions;
          }
          this.permissionMatrix.set(matrix);
        }),
        map(() => organization),
      );
  }
}

/** Repli du rôle administrateur si le backend n'a pas encore répondu. */
const ALL_PERMISSIONS = [
  ...MEMBER_PERMISSIONS,
  'organization.edit',
  'organization.manage_officers',
  'member.create',
  'member.edit',
  'member.delete',
  'member.invite',
  'tontine.create',
  'tontine.edit',
  'tontine.validate',
  'contribution.record',
  'contribution.confirm',
  'contribution.cancel',
  'draw.run',
  'draw.override',
  'draw.invalidate',
  'payout.record',
  'treasury.view',
  'treasury.manage',
  'report.view',
  'audit.view',
  'reminder.send',
];
