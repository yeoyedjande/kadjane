import { Injectable } from '@angular/core';

import { AuthTokens } from '../models/domain.models';

const STORAGE_KEY = 'kadjane.admin.session';

/** Conservation des jetons de session.
 *
 *  `sessionStorage` plutôt que `localStorage` : la session meurt avec l'onglet,
 *  ce qui limite l'exposition sur un poste partagé. Aucun mot de passe n'est
 *  jamais conservé.
 */
@Injectable({ providedIn: 'root' })
export class TokenStore {
  private cached: AuthTokens | null = null;

  read(): AuthTokens | null {
    if (this.cached) {
      return this.cached;
    }
    const raw = this.storage?.getItem(STORAGE_KEY);
    if (!raw) {
      return null;
    }
    try {
      this.cached = JSON.parse(raw) as AuthTokens;
      return this.cached;
    } catch {
      this.clear();
      return null;
    }
  }

  write(tokens: AuthTokens): void {
    this.cached = tokens;
    this.storage?.setItem(STORAGE_KEY, JSON.stringify(tokens));
  }

  clear(): void {
    this.cached = null;
    this.storage?.removeItem(STORAGE_KEY);
  }

  get accessToken(): string | null {
    return this.read()?.accessToken ?? null;
  }

  get refreshToken(): string | null {
    return this.read()?.refreshToken ?? null;
  }

  /** Vrai si le jeton d'accès est expiré ou sur le point de l'être. */
  isExpiring(marginSeconds = 30): boolean {
    const expiresAt = this.read()?.expiresAt;
    if (!expiresAt) {
      return true;
    }
    return new Date(expiresAt).getTime() - marginSeconds * 1000 <= Date.now();
  }

  private get storage(): Storage | null {
    return typeof sessionStorage === 'undefined' ? null : sessionStorage;
  }
}
