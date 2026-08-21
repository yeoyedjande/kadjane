import { Injectable, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { Observable, map, tap } from 'rxjs';

import { AuthSession, AuthTokens, User } from '../models/domain.models';
import { ApiClient } from './api-client.service';
import { TokenStore } from './token-store.service';

/** Session de l'administrateur connecté. */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly api = inject(ApiClient);
  private readonly tokens = inject(TokenStore);
  private readonly router = inject(Router);

  private readonly currentUser = signal<User | null>(null);

  readonly user = this.currentUser.asReadonly();
  readonly isAuthenticated = computed(() => this.currentUser() !== null);

  /** Une session existe peut-être déjà : à confirmer par `/auth/me`. */
  hasStoredSession(): boolean {
    return this.tokens.read() !== null;
  }

  login(identifier: string, password: string): Observable<AuthSession> {
    return this.api
      .post<AuthSession>('/auth/login', { identifier, password })
      .pipe(
        tap((session) => {
          this.tokens.write(session.tokens);
          this.currentUser.set(session.user);
        }),
      );
  }

  me(): Observable<User> {
    return this.api
      .get<User>('/auth/me')
      .pipe(tap((user) => this.currentUser.set(user)));
  }

  refresh(): Observable<AuthTokens> {
    const refreshToken = this.tokens.refreshToken;
    return this.api
      .post<AuthSession>('/auth/refresh', { refreshToken })
      .pipe(
        tap((session) => {
          this.tokens.write(session.tokens);
          this.currentUser.set(session.user);
        }),
        // Le contrat renvoie la session complète ; seul le couple de jetons
        // intéresse l'appelant.
        map((session) => session.tokens),
      );
  }

  /** Ferme la session côté serveur puis localement. */
  logout(redirect = true): void {
    if (this.tokens.refreshToken) {
      this.api.post('/auth/logout', {}).subscribe({
        next: () => undefined,
        error: () => undefined,
      });
    }
    this.clear();
    if (redirect) {
      void this.router.navigate(['/login']);
    }
  }

  /** Purge locale : utilisée aussi quand le serveur refuse la session. */
  clear(): void {
    this.tokens.clear();
    this.currentUser.set(null);
  }
}
