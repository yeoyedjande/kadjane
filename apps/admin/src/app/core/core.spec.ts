import {
  HttpClient,
  provideHttpClient,
  withInterceptors,
} from '@angular/common/http';
import {
  HttpTestingController,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { authInterceptor } from './interceptors/auth.interceptor';
import { ApiError } from './models/api.models';
import { ApiClient } from './services/api-client.service';
import { AuthService } from './services/auth.service';
import { MemberService, TontineService } from './services/domain.services';
import { SessionService } from './services/session.service';
import { TokenStore } from './services/token-store.service';
import { describeError } from './services/toast.service';

const API = 'http://localhost:8000/api/v1';

/** Cible de redirection minimale : le garde et l'interceptor renvoient vers
 *  `/login`, sans qu'il soit utile de charger l'écran réel. */
const LOGIN_ROUTE = [{ path: 'login', children: [] }];

function tokens(expiresInMinutes = 30) {
  return {
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    expiresAt: new Date(Date.now() + expiresInMinutes * 60_000).toISOString(),
  };
}

describe('ApiClient', () => {
  let http: HttpTestingController;
  let api: ApiClient;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
    api = TestBed.inject(ApiClient);
  });

  it("déballe l'enveloppe {success, data}", async () => {
    const promise = firstValue(api.get<{ id: string }>('/me'));
    const request = http.expectOne(`${API}/me`);
    request.flush({ success: true, data: { id: 'usr-1' } });

    await expect(promise).resolves.toEqual({ id: 'usr-1' });
  });

  it('expose meta séparément', async () => {
    const promise = firstValue(api.getWithMeta<number[]>('/x'));
    http.expectOne(`${API}/x`).flush({
      success: true,
      data: [1, 2],
      meta: { total: 2 },
    });

    await expect(promise).resolves.toEqual({ data: [1, 2], meta: { total: 2 } });
  });

  it('traduit une erreur métier en ApiError typée', async () => {
    const promise = firstValue(api.get('/organizations/x'));
    http.expectOne(`${API}/organizations/x`).flush(
      {
        success: false,
        error: { code: 'organization_not_found', message: 'Introuvable.' },
      },
      { status: 404, statusText: 'Not Found' },
    );

    await expect(promise).rejects.toBeInstanceOf(ApiError);
    await promise.catch((error: ApiError) => {
      expect(error.code).toBe('organization_not_found');
      expect(error.status).toBe(404);
    });
  });

  it('ignore les paramètres vides dans la requête', () => {
    api.get('/organizations/1/members', { page: 0, role: null, query: '' }).subscribe();
    const request = http.expectOne((r) => r.url === `${API}/organizations/1/members`);
    expect(request.request.params.get('page')).toBe('0');
    expect(request.request.params.has('role')).toBe(false);
    expect(request.request.params.has('query')).toBe(false);
  });
});

describe('authInterceptor', () => {
  let http: HttpTestingController;
  let client: HttpClient;
  let store: TokenStore;

  beforeEach(() => {
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideRouter(LOGIN_ROUTE),
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpTestingController);
    client = TestBed.inject(HttpClient);
    store = TestBed.inject(TokenStore);
  });

  it("ajoute l'en-tête Authorization", () => {
    store.write(tokens());
    client.get(`${API}/me`).subscribe();

    const request = http.expectOne(`${API}/me`);
    expect(request.request.headers.get('Authorization')).toBe('Bearer access-1');
  });

  it("n'authentifie pas la connexion", () => {
    store.write(tokens());
    client.post(`${API}/auth/login`, {}).subscribe();

    const request = http.expectOne(`${API}/auth/login`);
    expect(request.request.headers.has('Authorization')).toBe(false);
  });

  it('renouvelle la session sur 401 puis rejoue la requête', async () => {
    store.write(tokens());
    const promise = firstValue(client.get(`${API}/organizations`));

    http.expectOne(`${API}/organizations`).flush(
      { success: false, error: { code: 'session_expired', message: '' } },
      { status: 401, statusText: 'Unauthorized' },
    );

    // Un seul appel de renouvellement.
    const refresh = http.expectOne(`${API}/auth/refresh`);
    refresh.flush({
      success: true,
      data: { user: { id: 'usr-1' }, tokens: tokens() },
    });

    http.expectOne(`${API}/organizations`).flush({ success: true, data: [] });
    await expect(promise).resolves.toEqual({ success: true, data: [] });
  });

  it('purge la session quand le renouvellement échoue', async () => {
    store.write(tokens());
    const router = TestBed.inject(Router);
    const navigate = vi.spyOn(router, 'navigate').mockResolvedValue(true);
    const promise = firstValue(client.get(`${API}/organizations`));

    http.expectOne(`${API}/organizations`).flush(
      {},
      { status: 401, statusText: 'Unauthorized' },
    );
    http
      .expectOne(`${API}/auth/refresh`)
      .flush({}, { status: 401, statusText: 'Unauthorized' });

    // L'échec du renouvellement remonte l'erreur du refresh, déjà normalisée.
    await expect(promise).rejects.toBeInstanceOf(ApiError);
    expect(store.read()).toBeNull();
    expect(navigate).toHaveBeenCalledWith(['/login']);
  });

  it('ne tente aucun renouvellement sans jeton de rafraîchissement', async () => {
    const promise = firstValue(client.get(`${API}/organizations`));
    http.expectOne(`${API}/organizations`).flush(
      {},
      { status: 401, statusText: 'Unauthorized' },
    );

    http.expectNone(`${API}/auth/refresh`);
    await expect(promise).rejects.toBeTruthy();
  });
});

describe('AuthService', () => {
  let http: HttpTestingController;
  let auth: AuthService;
  let store: TokenStore;

  beforeEach(() => {
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideRouter(LOGIN_ROUTE), provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
    auth = TestBed.inject(AuthService);
    store = TestBed.inject(TokenStore);
  });

  it('conserve les jetons et l’utilisateur après connexion', async () => {
    const promise = firstValue(auth.login('yeo@kadjane.app', 'kadjane'));

    const request = http.expectOne(`${API}/auth/login`);
    expect(request.request.body).toEqual({
      identifier: 'yeo@kadjane.app',
      password: 'kadjane',
    });
    request.flush({
      success: true,
      data: { user: { id: 'usr-1', firstName: 'Yedjane' }, tokens: tokens() },
    });

    await promise;
    expect(auth.isAuthenticated()).toBe(true);
    expect(auth.user()?.firstName).toBe('Yedjane');
    expect(store.accessToken).toBe('access-1');
  });

  it('purge la session à la déconnexion', () => {
    store.write(tokens());
    auth.logout(false);

    http.expectOne(`${API}/auth/logout`).flush({ success: true, data: {} });
    expect(store.read()).toBeNull();
    expect(auth.isAuthenticated()).toBe(false);
  });

  it('détecte un jeton expiré', () => {
    store.write(tokens(-1));
    expect(store.isExpiring()).toBe(true);
  });
});

describe('SessionService et permissions', () => {
  let http: HttpTestingController;
  let session: SessionService;

  beforeEach(() => {
    sessionStorage.clear();
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideRouter(LOGIN_ROUTE), provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
    session = TestBed.inject(SessionService);
  });

  function load(role = 'treasurer', permissions = ['contribution.record']) {
    const promise = firstValue(session.load());
    http.expectOne(`${API}/organizations`).flush({
      success: true,
      data: [{ id: 'org-1', name: 'Association Solidarité', currency: 'XOF' }],
    });
    http
      .expectOne((r) => r.url === `${API}/organizations/org-1/membership`)
      .flush({ success: true, data: { id: 'mbr-1', role } });
    // Les droits sont désormais lus par membre, et non par nom de rôle : un
    // rôle sur mesure n'a pas d'entrée dans une matrice indexée par rôle.
    http
      .expectOne((r) => r.url === `${API}/me/permissions`)
      .flush({
        success: true,
        data: [
          {
            organizationId: 'org-1',
            memberId: 'mbr-1',
            role,
            roleId: null,
            roleName: role,
            permissions,
          },
        ],
      });
    return promise;
  }

  it("sélectionne l'organisation et applique les droits du serveur", async () => {
    await load('treasurer', ['contribution.record', 'treasury.view']);

    expect(session.organizationId()).toBe('org-1');
    expect(session.currency()).toBe('XOF');
    expect(session.role()).toBe('treasurer');
    expect(session.can('contribution.record')).toBe(true);
    expect(session.can('treasury.view')).toBe(true);
    // Le serveur ne l'accorde pas : l'interface le masque.
    expect(session.can('draw.run')).toBe(false);
  });

  it('reconnaît le super administrateur plateforme', async () => {
    await load('super_admin', ['organization.edit']);
    expect(session.isPlatformAdmin()).toBe(true);
  });

  it('remet tout à zéro à la déconnexion', async () => {
    await load();
    session.reset();
    expect(session.organizationId()).toBeNull();
    expect(session.permissions()).toEqual([]);
  });
});

describe('Services métier', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
  });

  it('MemberService pagine et filtre', async () => {
    const members = TestBed.inject(MemberService);
    const promise = firstValue(
      members.list('org-1', { page: 1, pageSize: 20, query: 'awa', role: 'treasurer' }),
    );

    const request = http.expectOne(
      (r) => r.url === `${API}/organizations/org-1/members`,
    );
    expect(request.request.params.get('page')).toBe('1');
    expect(request.request.params.get('query')).toBe('awa');
    expect(request.request.params.get('role')).toBe('treasurer');

    request.flush({
      success: true,
      data: { items: [], page: 1, pageSize: 20, hasMore: false, total: 0 },
    });
    await expect(promise).resolves.toMatchObject({ total: 0 });
  });

  it('MemberService envoie le membre à créer', () => {
    const members = TestBed.inject(MemberService);
    members
      .create('org-1', {
        firstName: 'Konan',
        lastName: 'KOUAME',
        phone: '+225 07 00 00 00 13',
        role: 'member',
      })
      .subscribe();

    const request = http.expectOne(`${API}/organizations/org-1/members`);
    expect(request.request.method).toBe('POST');
    expect(request.request.body.firstName).toBe('Konan');
  });

  it('TontineService crée une tontine avec ses participants', () => {
    const tontines = TestBed.inject(TontineService);
    tontines
      .create('org-1', {
        name: 'Tontine Solidarité',
        contributionAmount: 50000,
        currency: 'XOF',
        frequency: 'monthly',
        allocationMode: 'monthly_draw',
        startDate: '2026-08-01',
        dueDayOfPeriod: 5,
        memberIds: ['mbr-1', 'mbr-2'],
        requireAllContributionsBeforeDraw: true,
        allowDrawOverride: true,
      })
      .subscribe();

    const request = http.expectOne(`${API}/organizations/org-1/tontines`);
    expect(request.request.body.memberIds).toHaveLength(2);
    expect(request.request.body.allocationMode).toBe('monthly_draw');
  });
});

describe('Traduction des erreurs métier', () => {
  it('affiche un message lisible plutôt qu’un code technique', () => {
    expect(describeError(new ApiError('alreadyDrawn', 'x', 409))).toContain(
      'déjà été désigné',
    );
    expect(
      describeError(
        new ApiError('missingContributions', 'x', 409, { remaining_count: 1 }),
      ),
    ).toBe('1 cotisation reste à régler.');
    expect(
      describeError(
        new ApiError('missingContributions', 'x', 409, { remaining_count: 3 }),
      ),
    ).toBe('3 cotisations restent à régler.');
    expect(describeError(new ApiError('permission_denied', 'x', 403))).toContain(
      'rôle',
    );
    expect(describeError(new Error('boom'), 'Repli')).toBe('Repli');
  });
});

/** Promesse résolue à la première valeur émise. */
function firstValue<T>(source: {
  subscribe: (observer: {
    next: (value: T) => void;
    error: (error: unknown) => void;
  }) => unknown;
}): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    source.subscribe({ next: resolve, error: reject });
  });
}
