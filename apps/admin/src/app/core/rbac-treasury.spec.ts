import { provideHttpClient } from '@angular/common/http';
import {
  HttpTestingController,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';
import { firstValueFrom } from 'rxjs';

import {
  CampaignService,
  CashboxService,
  RbacService,
} from './services/rbac-treasury.services';
import { SessionService } from './services/session.service';

const API = 'http://localhost:8000/api/v1';

describe('RBAC administrable', () => {
  let http: HttpTestingController;
  let rbac: RbacService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
    rbac = TestBed.inject(RbacService);
  });

  it('sépare le catalogue de ses catégories', async () => {
    const promise = firstValueFrom(rbac.catalog());
    http.expectOne(`${API}/permissions`).flush({
      success: true,
      data: [
        {
          id: 'p1',
          code: 'cashbox.create',
          name: 'Créer une caisse',
          description: '',
          category: 'cashbox',
        },
      ],
      meta: { categories: ['cashbox', 'members'] },
    });

    const body = await promise;
    expect(body.permissions[0].code).toBe('cashbox.create');
    expect(body.categories).toEqual(['cashbox', 'members']);
  });

  it('remplace les permissions plutôt que de les fusionner', async () => {
    const promise = firstValueFrom(
      rbac.setPermissions('org-1', 'rol-1', ['cashbox.view', 'payment.view']),
    );
    const request = http.expectOne(
      `${API}/organizations/org-1/roles/rol-1/permissions`,
    );

    // Un PUT, pas un PATCH : deux administrateurs qui enregistrent en même
    // temps ne doivent pas voir leurs intentions fusionner.
    expect(request.request.method).toBe('PUT');
    expect(request.request.body).toEqual({
      permissions: ['cashbox.view', 'payment.view'],
    });

    request.flush({ success: true, data: { id: 'rol-1', permissions: [] } });
    await promise;
  });
});

describe('Droits de session', () => {
  let http: HttpTestingController;
  let session: SessionService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpTestingController);
    session = TestBed.inject(SessionService);
  });

  function load(permissions: string[], role = 'responsable-cotisations') {
    const promise = firstValueFrom(session.load());
    http.expectOne(`${API}/organizations`).flush({
      success: true,
      data: [{ id: 'org-1', name: 'Association', currency: 'XOF' }],
    });
    http
      .expectOne((r) => r.url === `${API}/organizations/org-1/membership`)
      .flush({ success: true, data: { id: 'mbr-1', role } });
    http.expectOne((r) => r.url === `${API}/me/permissions`).flush({
      success: true,
      data: [
        {
          organizationId: 'org-1',
          memberId: 'mbr-1',
          role,
          roleId: 'rol-9',
          roleName: 'Responsable Cotisations',
          permissions,
        },
      ],
    });
    return promise;
  }

  it('applique les droits d\'un rôle sur mesure', async () => {
    // Une matrice indexée par nom de rôle n'aurait aucune entrée pour lui :
    // c'est précisément pourquoi les droits sont lus par membre.
    await load(['contribution.view', 'contribution.create', 'payment.view']);

    expect(session.roleName()).toBe('Responsable Cotisations');
    expect(session.can('contribution.create')).toBe(true);
    expect(session.can('payment.confirm')).toBe(false);
    expect(session.canAny('payment.confirm', 'payment.view')).toBe(true);
  });

  it('ne montre aucune action d\'écriture tant que les droits ne sont pas connus', async () => {
    // Régression : le repli servait `ALL_PERMISSIONS` et affichait tous les
    // boutons d'administration quand l'API tardait à répondre.
    await load([]);

    expect(session.can('member.view')).toBe(true);
    expect(session.can('cashbox.create')).toBe(false);
    expect(session.can('role.assign')).toBe(false);
    expect(session.can('permission.assign')).toBe(false);
  });
});

describe('Caisses et cotisations', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
  });

  it('lit le journal paginé avec son total', async () => {
    const cashboxes = TestBed.inject(CashboxService);
    const promise = firstValueFrom(
      cashboxes.transactions('box-1', { limit: 25, offset: 25 }),
    );
    const request = http.expectOne(
      (r) => r.url === `${API}/cashboxes/box-1/transactions`,
    );

    expect(request.request.params.get('offset')).toBe('25');
    request.flush({
      success: true,
      data: [{ id: 't1' }],
      meta: { total: 40 },
    });

    const body = await promise;
    expect(body.total).toBe(40);
    expect(body.items).toHaveLength(1);
  });

  it('annule un mouvement sans le supprimer', async () => {
    const cashboxes = TestBed.inject(CashboxService);
    const promise = firstValueFrom(
      cashboxes.cancelTransaction('t1', 'Saisie en double'),
    );
    const request = http.expectOne(`${API}/cash-transactions/t1/cancel`);

    // Un POST vers `/cancel`, jamais un DELETE : aucune écriture financière
    // ne quitte le journal.
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({
      reason: 'Saisie en double',
      reversed: false,
    });

    request.flush({ success: true, data: { id: 't1', status: 'cancelled' } });
    await promise;
  });

  it('enregistre un règlement et récupère la ligne recalculée', async () => {
    const campaigns = TestBed.inject(CampaignService);
    const promise = firstValueFrom(
      campaigns.pay('entry-1', { amount: 20000, paymentMethod: 'cash' }),
    );
    http.expectOne(`${API}/contribution-entries/entry-1/payments`).flush({
      success: true,
      data: {
        payment: { id: 'pay-1', amount: 20000 },
        entry: { id: 'entry-1', paidAmount: 20000, remainingAmount: 30000, status: 'partial' },
      },
    });

    const body = await promise;
    // Le client ne recalcule rien : il lit ce que le backend a établi.
    expect(body.entry.status).toBe('partial');
    expect(body.entry.remainingAmount).toBe(30000);
  });
});
