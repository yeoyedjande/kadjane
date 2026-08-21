import { Pipe, PipeTransform, inject } from '@angular/core';

import { SessionService } from '../services/session.service';

/** `600000` → `600 000 FCFA`.
 *
 *  La devise vient de l'organisation active ; « FCFA » n'est qu'un repli.
 */
@Pipe({ name: 'money' })
export class MoneyPipe implements PipeTransform {
  private readonly session = inject(SessionService);

  transform(value: number | null | undefined, currency?: string): string {
    const amount = Number(value ?? 0);
    const code = currency ?? this.session.currency();
    return `${formatAmount(amount)} ${label(code)}`;
  }
}

/** Montant seul, sans devise (colonnes serrées). */
@Pipe({ name: 'amount' })
export class AmountPipe implements PipeTransform {
  transform(value: number | null | undefined): string {
    return formatAmount(Number(value ?? 0));
  }
}

/** `2026-08-21T…` → `21 août 2026`. */
@Pipe({ name: 'frDate' })
export class FrDatePipe implements PipeTransform {
  transform(value: string | Date | null | undefined, withTime = false): string {
    if (!value) {
      return '—';
    }
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) {
      return '—';
    }
    const options: Intl.DateTimeFormatOptions = withTime
      ? {
          day: 'numeric',
          month: 'long',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
        }
      : { day: 'numeric', month: 'long', year: 'numeric' };
    return new Intl.DateTimeFormat('fr-FR', options).format(date);
  }
}

/** Traduit les codes d'énumération pour l'affichage. */
@Pipe({ name: 'label' })
export class LabelPipe implements PipeTransform {
  transform(value: string | null | undefined): string {
    if (!value) {
      return '—';
    }
    return LABELS[value] ?? value;
  }
}

function formatAmount(amount: number): string {
  const rounded = Math.round(amount * 100) / 100;
  return new Intl.NumberFormat('fr-FR', {
    maximumFractionDigits: Number.isInteger(rounded) ? 0 : 2,
  }).format(rounded);
}

function label(currency: string): string {
  return currency === 'XOF' ? 'FCFA' : currency;
}

export const LABELS: Record<string, string> = {
  // Rôles
  super_admin: 'Super administrateur',
  admin: 'Administrateur',
  president: 'Président',
  treasurer: 'Trésorier',
  auditor: 'Commissaire aux comptes',
  member: 'Membre',
  // Statuts de membre et d'organisation
  active: 'Actif',
  inactive: 'Inactif',
  suspended: 'Suspendu',
  pending: 'En attente',
  archived: 'Archivé',
  // Tontines
  draft: 'Brouillon',
  completed: 'Terminée',
  cancelled: 'Annulée',
  monthly_draw: 'Tirage périodique',
  full_order_draw: 'Ordre tiré au sort',
  manual_order: 'Ordre manuel',
  weekly: 'Hebdomadaire',
  biweekly: 'Quinzaine',
  monthly: 'Mensuelle',
  custom: 'Personnalisée',
  // Cycles
  upcoming: 'À venir',
  collecting: 'Collecte',
  ready_for_draw: 'Prêt pour le tirage',
  drawn: 'Tiré',
  paid_out: 'Versé',
  closed: 'Clôturé',
  // Cotisations et paiements
  partial: 'Partiel',
  paid: 'Payé',
  late: 'En retard',
  confirmed: 'Confirmé',
  rejected: 'Rejeté',
  processing: 'En cours',
  failed: 'Échec',
  designated: 'Désigné',
  payout_pending: 'Versement en attente',
  // Moyens de paiement
  cash: 'Espèces',
  wave: 'Wave',
  orange_money: 'Orange Money',
  mtn_momo: 'MTN MoMo',
  moov_money: 'Moov Money',
  bank_transfer: 'Virement bancaire',
  other: 'Autre',
  // Trésorerie
  income: 'Entrée',
  expense: 'Sortie',
  contribution: 'Cotisation',
  payout: 'Versement',
  donation: 'Don',
  fee: 'Frais',
  event: 'Événement',
  social_aid: 'Aide sociale',
  // Relances
  due_today: 'Échéance du jour',
  escalated: 'Relance escaladée',
  // Tirages
  periodic_draw: 'Tirage périodique',
  order_draw: 'Ordre complet',
  scheduled: 'Programmé',
  invalidated: 'Invalidé',
  // Actions d'audit
  'tontine.created': 'Tontine créée',
  'tontine.updated': 'Tontine modifiée',
  'tontine.status_changed': 'Statut de tontine',
  'contribution.recorded': 'Paiement enregistré',
  'contribution.confirmed': 'Cotisation confirmée',
  'contribution.cancelled': 'Paiement annulé',
  'draw.completed': 'Tirage effectué',
  'draw.overridden': 'Tirage forcé',
  'draw.invalidated': 'Tirage invalidé',
  'beneficiary.designated': 'Bénéficiaire désigné',
  'payout.recorded': 'Versement enregistré',
  'payout.confirmed': 'Versement confirmé',
  'order.generated': 'Ordre de passage défini',
  'member.created': 'Membre ajouté',
  'member.updated': 'Membre modifié',
  'member.role_changed': 'Rôle modifié',
  'organization.updated': 'Organisation modifiée',
  'transaction.recorded': 'Mouvement de caisse',
  // Notifications
  payment_confirmed: 'Paiement confirmé',
  draw_result: 'Résultat de tirage',
  payout_done: 'Cagnotte versée',
  new_member: 'Nouveau membre',
  announcement: 'Annonce',
  contribution_due: 'Cotisation à venir',
  contribution_late: 'Cotisation en retard',
};
