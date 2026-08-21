import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, catchError, map, throwError } from 'rxjs';

import { environment } from '../../../environments/environment';
import { ApiEnvelope, ApiError } from '../models/api.models';

type QueryValue = string | number | boolean | null | undefined;

/** Accès HTTP au backend Kadjane.
 *
 *  Un seul endroit sait que l'API enveloppe ses réponses dans
 *  `{success, data, meta}` : les services métier reçoivent directement le
 *  contenu utile, et les erreurs arrivent typées en `ApiError`.
 */
@Injectable({ providedIn: 'root' })
export class ApiClient {
  private readonly http = inject(HttpClient);
  private readonly base = environment.apiBaseUrl;

  get<T>(path: string, query?: Record<string, QueryValue>): Observable<T> {
    return this.unwrap(
      this.http.get<ApiEnvelope<T>>(this.url(path), { params: this.params(query) }),
    );
  }

  /** Variante qui expose aussi `meta` (totaux, pagination). */
  getWithMeta<T>(
    path: string,
    query?: Record<string, QueryValue>,
  ): Observable<{ data: T; meta: Record<string, unknown> }> {
    return this.http
      .get<ApiEnvelope<T>>(this.url(path), { params: this.params(query) })
      .pipe(
        map((body) => ({ data: body.data, meta: body.meta ?? {} })),
        catchError((error: unknown) => throwError(() => toApiError(error))),
      );
  }

  post<T>(path: string, body?: unknown): Observable<T> {
    return this.unwrap(this.http.post<ApiEnvelope<T>>(this.url(path), body ?? {}));
  }

  patch<T>(path: string, body: unknown): Observable<T> {
    return this.unwrap(this.http.patch<ApiEnvelope<T>>(this.url(path), body));
  }

  put<T>(path: string, body: unknown): Observable<T> {
    return this.unwrap(this.http.put<ApiEnvelope<T>>(this.url(path), body));
  }

  delete<T>(path: string): Observable<T> {
    return this.unwrap(this.http.delete<ApiEnvelope<T>>(this.url(path)));
  }

  upload<T>(path: string, file: File): Observable<T> {
    const form = new FormData();
    form.append('file', file);
    return this.unwrap(this.http.post<ApiEnvelope<T>>(this.url(path), form));
  }

  private url(path: string): string {
    return `${this.base}${path}`;
  }

  private params(query?: Record<string, QueryValue>): HttpParams {
    let params = new HttpParams();
    for (const [key, value] of Object.entries(query ?? {})) {
      if (value !== null && value !== undefined && value !== '') {
        params = params.set(key, String(value));
      }
    }
    return params;
  }

  private unwrap<T>(source: Observable<ApiEnvelope<T>>): Observable<T> {
    return source.pipe(
      map((body) => body.data),
      catchError((error: unknown) => throwError(() => toApiError(error))),
    );
  }
}

/** Traduit une erreur HTTP en erreur métier lisible. */
export function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) {
    return error;
  }
  if (error instanceof HttpErrorResponse) {
    const body = error.error?.error;
    if (body?.code) {
      return new ApiError(body.code, body.message, error.status, body.details ?? null);
    }
    if (error.status === 0) {
      return new ApiError(
        'network_error',
        "Le serveur est injoignable. Vérifiez que l'API est démarrée.",
        0,
      );
    }
    return new ApiError(
      `http_${error.status}`,
      error.statusText || 'Une erreur est survenue.',
      error.status,
    );
  }
  return new ApiError('unexpected', 'Une erreur inattendue est survenue.', 0);
}
