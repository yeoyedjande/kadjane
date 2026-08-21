import { Injectable, signal } from '@angular/core';

import { ApiError } from '../models/api.models';

export type ToastKind = 'success' | 'error' | 'info';

export interface Toast {
  id: number;
  kind: ToastKind;
  message: string;
}

/** Messages de retour affichés en haut à droite.
 *
 *  Les erreurs métier du backend sont traduites en français lisible : aucune
 *  exception technique n'atteint l'administrateur.
 */
@Injectable({ providedIn: 'root' })
export class ToastService {
  private readonly items = signal<Toast[]>([]);
  private counter = 0;

  readonly toasts = this.items.asReadonly();

  success(message: string): void {
    this.push('success', message);
  }

  info(message: string): void {
    this.push('info', message);
  }

  error(message: string): void {
    this.push('error', message);
  }

  /** Traduit puis affiche une erreur d'API. */
  fromError(error: unknown, fallback = 'Une erreur est survenue.'): void {
    this.error(describeError(error, fallback));
  }

  dismiss(id: number): void {
    this.items.update((list) => list.filter((toast) => toast.id !== id));
  }

  private push(kind: ToastKind, message: string): void {
    const id = ++this.counter;
    this.items.update((list) => [...list, { id, kind, message }]);
    setTimeout(() => this.dismiss(id), kind === 'error' ? 7000 : 4000);
  }
}

/** Messages métier connus, dans la langue de l'utilisateur. */
const MESSAGES: Record<string, string> = {
  invalid_credentials: 'Identifiants invalides.',
  session_expired: 'Votre session a expiré, reconnectez-vous.',
  permission_denied: "Votre rôle ne permet pas cette action.",
  not_found: 'Ressource introuvable.',
  organization_not_found: 'Organisation introuvable.',
  member_not_found: 'Membre introuvable.',
  tontine_not_found: 'Tontine introuvable.',
  phone_already_used: 'Ce numéro de téléphone est déjà utilisé.',
  email_already_used: 'Cette adresse e-mail est déjà utilisée.',
  member_already_exists: "Ce membre fait déjà partie de l'organisation.",
  missingContributions: 'Des cotisations restent à régler.',
  alreadyDrawn: 'Un bénéficiaire a déjà été désigné pour cette période.',
  tontineNotActive: "La tontine n'est pas active.",
  noEligibleParticipant: 'Plus aucun participant n’est éligible au tirage.',
  orderAlreadyDefined: "L'ordre de passage est déjà défini.",
  override_disabled: 'Le forçage du tirage est désactivé pour cette tontine.',
  override_reason_required: 'Une justification est obligatoire pour forcer le tirage.',
  tontine_locked: 'Ces réglages ne sont plus modifiables après activation.',
  payout_already_recorded: 'La cagnotte de cette période a déjà été versée.',
  validation_error: 'Certaines données saisies sont invalides.',
  network_error: "Le serveur est injoignable. Vérifiez que l'API est démarrée.",
  file_too_large: 'Le justificatif dépasse 5 Mo.',
  unsupported_file_type: 'Format non accepté : image (JPEG, PNG, WebP) ou PDF.',
};

export function describeError(error: unknown, fallback = 'Une erreur est survenue.'): string {
  if (error instanceof ApiError) {
    const known = MESSAGES[error.code];
    if (known) {
      const remaining = error.details?.['remaining_count'];
      if (error.code === 'missingContributions' && typeof remaining === 'number') {
        return remaining <= 1
          ? '1 cotisation reste à régler.'
          : `${remaining} cotisations restent à régler.`;
      }
      return known;
    }
    return error.message || fallback;
  }
  return fallback;
}
