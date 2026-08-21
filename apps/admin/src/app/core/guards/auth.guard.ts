import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { catchError, map, of, switchMap } from 'rxjs';

import { AuthService } from '../services/auth.service';
import { SessionService } from '../services/session.service';

/** Laisse entrer uniquement une session confirmée par le serveur.
 *
 *  La présence d'un jeton ne suffit pas : `/auth/me` tranche.
 */
export const authGuard: CanActivateFn = (_route, state) => {
  const auth = inject(AuthService);
  const session = inject(SessionService);
  const router = inject(Router);

  const toLogin = () =>
    router.createUrlTree(['/login'], { queryParams: { redirect: state.url } });

  if (auth.isAuthenticated() && session.organizationId()) {
    return true;
  }
  if (!auth.hasStoredSession()) {
    return toLogin();
  }

  return auth.me().pipe(
    switchMap(() => session.load()),
    map(() => true),
    catchError(() => {
      auth.clear();
      return of(toLogin());
    }),
  );
};

/** Empêche de revenir sur l'écran de connexion en étant déjà connecté. */
export const guestGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isAuthenticated() ? router.createUrlTree(['/dashboard']) : true;
};
