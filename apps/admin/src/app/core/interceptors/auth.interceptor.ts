import {
  HttpErrorResponse,
  HttpEvent,
  HttpHandlerFn,
  HttpRequest,
} from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import {
  BehaviorSubject,
  Observable,
  catchError,
  filter,
  switchMap,
  take,
  throwError,
} from 'rxjs';

import { AuthTokens } from '../models/domain.models';
import { AuthService } from '../services/auth.service';
import { TokenStore } from '../services/token-store.service';

/** Une seule tentative de renouvellement à la fois : les requêtes
 *  concurrentes attendent le même jeton au lieu de déclencher une rafale. */
let refreshing = false;
const refreshed = new BehaviorSubject<AuthTokens | null>(null);

/** Routes publiques : un 401 y signifie « identifiants refusés », pas
 *  « session expirée ». Aucun renouvellement ne doit être tenté. */
function isPublic(url: string): boolean {
  return (
    url.includes('/auth/login') ||
    url.includes('/auth/register') ||
    url.includes('/auth/refresh')
  );
}

export function authInterceptor(
  request: HttpRequest<unknown>,
  next: HttpHandlerFn,
): Observable<HttpEvent<unknown>> {
  const tokens = inject(TokenStore);
  const auth = inject(AuthService);
  const router = inject(Router);

  const authorized = isPublic(request.url) ? request : withToken(request, tokens);

  return next(authorized).pipe(
    catchError((error: unknown) => {
      const unauthorized =
        error instanceof HttpErrorResponse && error.status === 401;

      if (!unauthorized || isPublic(request.url) || !tokens.refreshToken) {
        if (unauthorized && !isPublic(request.url)) {
          auth.clear();
          void router.navigate(['/login']);
        }
        return throwError(() => error);
      }

      if (refreshing) {
        // Attendre le renouvellement en cours, puis rejouer une seule fois.
        return refreshed.pipe(
          filter((value): value is AuthTokens => value !== null),
          take(1),
          switchMap(() => next(withToken(request, tokens))),
        );
      }

      refreshing = true;
      refreshed.next(null);

      return auth.refresh().pipe(
        switchMap((renewed) => {
          refreshing = false;
          refreshed.next(renewed);
          return next(withToken(request, tokens));
        }),
        catchError((refreshError: unknown) => {
          refreshing = false;
          auth.clear();
          void router.navigate(['/login']);
          return throwError(() => refreshError);
        }),
      );
    }),
  );
}

function withToken(
  request: HttpRequest<unknown>,
  tokens: TokenStore,
): HttpRequest<unknown> {
  const token = tokens.accessToken;
  return token
    ? request.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    : request;
}
