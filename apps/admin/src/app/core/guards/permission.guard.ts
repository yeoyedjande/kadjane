import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

import { SessionService } from '../services/session.service';
import { ToastService } from '../services/toast.service';

/** Masque une route à qui n'a pas la permission.
 *
 *  Ce garde est un confort d'interface, **pas** une sécurité : le backend
 *  refuse de toute façon l'opération. Il évite simplement d'ouvrir un écran
 *  qui n'afficherait que des erreurs 403.
 */
export function permissionGuard(...permissions: string[]): CanActivateFn {
  return () => {
    const session = inject(SessionService);
    const toast = inject(ToastService);
    const router = inject(Router);

    if (session.canAny(...permissions)) {
      return true;
    }

    toast.error("Vous n'avez pas accès à cette section.");
    return router.createUrlTree(['/dashboard']);
  };
}
