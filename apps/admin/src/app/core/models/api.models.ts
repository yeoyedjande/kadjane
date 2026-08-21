/** Enveloppe standard de l'API Kadjane. */
export interface ApiEnvelope<T> {
  success: boolean;
  data: T;
  meta?: Record<string, unknown>;
}

export interface ApiErrorBody {
  code: string;
  message: string;
  details?: Record<string, unknown> | null;
}

/** Erreur métier normalisée : jamais une exception technique brute. */
export class ApiError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number,
    readonly details: Record<string, unknown> | null = null,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  /** Erreurs par champ renvoyées par un 422. */
  get fieldErrors(): Record<string, string> {
    const errors = this.details?.['errors'];
    return errors && typeof errors === 'object'
      ? (errors as Record<string, string>)
      : {};
  }
}

export interface Page<T> {
  items: T[];
  page: number;
  pageSize: number;
  hasMore: boolean;
  total: number;
}

export interface PageQuery {
  page?: number;
  pageSize?: number;
  query?: string;
}
