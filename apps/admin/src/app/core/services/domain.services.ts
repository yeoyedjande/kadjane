import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';

import { Page } from '../models/api.models';
import {
  Attachment,
  AuditLog,
  Beneficiary,
  ContributionLine,
  ContributionPayment,
  ContributionTotals,
  Dashboard,
  DrawEligibility,
  DuesEntry,
  DuesPaymentPayload,
  DuesPlan,
  DuesPlanPayload,
  DuesPlanStatus,
  DrawSession,
  Member,
  MemberPayload,
  MemberStatus,
  Organization,
  OrgRole,
  Payout,
  PayoutPayload,
  PaymentPayload,
  ReminderTarget,
  ReportSnapshot,
  Tontine,
  TontineCycle,
  TontineParticipant,
  TontinePayload,
  TontineSummary,
  TreasurySnapshot,
  AppNotification,
  CashTransaction,
  TransactionType,
} from '../models/domain.models';
import { ApiClient } from './api-client.service';

/** Un service par domaine : les écrans ne construisent jamais d'URL. */

@Injectable({ providedIn: 'root' })
export class OrganizationService {
  private readonly api = inject(ApiClient);

  list(): Observable<Organization[]> {
    return this.api.get<Organization[]>('/organizations');
  }

  byId(id: string): Observable<Organization> {
    return this.api.get<Organization>(`/organizations/${id}`);
  }

  update(id: string, changes: Partial<Organization>): Observable<Organization> {
    return this.api.patch<Organization>(`/organizations/${id}`, changes);
  }

  setStatus(id: string, status: Organization['status']): Observable<Organization> {
    return this.api.patch<Organization>(`/organizations/${id}`, { status });
  }

  dashboard(id: string): Observable<Dashboard> {
    return this.api.get<Dashboard>(`/organizations/${id}/dashboard`);
  }

  officers(id: string): Observable<Member[]> {
    return this.api.get<Member[]>(`/organizations/${id}/officers`);
  }
}

export interface MemberQuery {
  page?: number;
  pageSize?: number;
  query?: string;
  role?: OrgRole | null;
  status?: MemberStatus | null;
}

@Injectable({ providedIn: 'root' })
export class MemberService {
  private readonly api = inject(ApiClient);

  list(organizationId: string, query: MemberQuery = {}): Observable<Page<Member>> {
    return this.api.get<Page<Member>>(`/organizations/${organizationId}/members`, {
      page: query.page ?? 0,
      pageSize: query.pageSize ?? 20,
      query: query.query ?? '',
      role: query.role ?? null,
      status: query.status ?? null,
    });
  }

  create(organizationId: string, payload: MemberPayload): Observable<Member> {
    return this.api.post<Member>(`/organizations/${organizationId}/members`, payload);
  }

  update(
    organizationId: string,
    memberId: string,
    changes: Partial<MemberPayload>,
  ): Observable<Member> {
    return this.api.patch<Member>(
      `/organizations/${organizationId}/members/${memberId}`,
      changes,
    );
  }

  byId(organizationId: string, memberId: string): Observable<Member> {
    return this.api.get<Member>(
      `/organizations/${organizationId}/members/${memberId}`,
    );
  }

  /** Retire un membre de l'organisation.
   *
   *  Le backend refuse la suppression d'un membre engagé dans une tontine
   *  (`member_has_history`) : son historique de cotisations serait effacé en
   *  cascade. Dans ce cas, la désactivation est la bonne réponse.
   */
  remove(organizationId: string, memberId: string): Observable<{ deleted: boolean }> {
    return this.api.delete<{ deleted: boolean }>(
      `/organizations/${organizationId}/members/${memberId}`,
    );
  }
}

/** Cotisations de caisse : les sommes dues à l'association, hors tontine.
 *
 *  Le backend engendre les échéances à la lecture : appeler `plans` ou
 *  `entries` suffit à faire apparaître les périodes écoulées.
 */
@Injectable({ providedIn: 'root' })
export class DuesService {
  private readonly api = inject(ApiClient);

  plans(organizationId: string): Observable<DuesPlan[]> {
    return this.api.get<DuesPlan[]>(`/organizations/${organizationId}/dues-plans`);
  }

  createPlan(organizationId: string, payload: DuesPlanPayload): Observable<DuesPlan> {
    return this.api.post<DuesPlan>(
      `/organizations/${organizationId}/dues-plans`,
      payload,
    );
  }

  updatePlan(
    organizationId: string,
    planId: string,
    changes: Partial<DuesPlanPayload> & { status?: DuesPlanStatus },
  ): Observable<DuesPlan> {
    return this.api.patch<DuesPlan>(
      `/organizations/${organizationId}/dues-plans/${planId}`,
      changes,
    );
  }

  entries(
    organizationId: string,
    planId: string,
    query: { period?: number | null; memberId?: string | null } = {},
  ): Observable<DuesEntry[]> {
    return this.api.get<DuesEntry[]>(
      `/organizations/${organizationId}/dues-plans/${planId}/entries`,
      { period: query.period ?? null, memberId: query.memberId ?? null },
    );
  }

  /** Échéances non soldées : ce que le trésorier réclame. */
  outstanding(organizationId: string): Observable<DuesEntry[]> {
    return this.api.get<DuesEntry[]>(
      `/organizations/${organizationId}/dues-outstanding`,
    );
  }

  recordPayment(entryId: string, payload: DuesPaymentPayload): Observable<unknown> {
    return this.api.post(`/dues-entries/${entryId}/payments`, payload);
  }
}

@Injectable({ providedIn: 'root' })
export class TontineService {
  private readonly api = inject(ApiClient);

  list(organizationId: string): Observable<TontineSummary[]> {
    return this.api.get<TontineSummary[]>(`/organizations/${organizationId}/tontines`);
  }

  create(organizationId: string, payload: TontinePayload): Observable<Tontine> {
    return this.api.post<Tontine>(`/organizations/${organizationId}/tontines`, payload);
  }

  byId(tontineId: string): Observable<Tontine> {
    return this.api.get<Tontine>(`/tontines/${tontineId}`);
  }

  summary(tontineId: string): Observable<TontineSummary> {
    return this.api.get<TontineSummary>(`/tontines/${tontineId}/summary`);
  }

  update(tontineId: string, changes: Record<string, unknown>): Observable<Tontine> {
    return this.api.patch<Tontine>(`/tontines/${tontineId}`, changes);
  }

  setStatus(tontineId: string, status: Tontine['status']): Observable<Tontine> {
    return this.api.patch<Tontine>(`/tontines/${tontineId}/status`, { status });
  }

  participants(tontineId: string): Observable<TontineParticipant[]> {
    return this.api.get<TontineParticipant[]>(`/tontines/${tontineId}/participants`);
  }

  setOrder(tontineId: string, participantIds: string[]): Observable<TontineParticipant[]> {
    return this.api.put<TontineParticipant[]>(
      `/tontines/${tontineId}/participants/order`,
      { participantIds },
    );
  }

  cycles(tontineId: string): Observable<TontineCycle[]> {
    return this.api.get<TontineCycle[]>(`/tontines/${tontineId}/cycles`);
  }

  cycle(cycleId: string): Observable<TontineCycle> {
    return this.api.get<TontineCycle>(`/cycles/${cycleId}`);
  }
}

@Injectable({ providedIn: 'root' })
export class ContributionService {
  private readonly api = inject(ApiClient);

  forCycle(
    tontineId: string,
    cycleId: string,
    filters: { status?: string | null; search?: string } = {},
  ): Observable<{ lines: ContributionLine[]; totals: ContributionTotals }> {
    return this.api
      .getWithMeta<ContributionLine[]>(
        `/tontines/${tontineId}/cycles/${cycleId}/contributions`,
        { status: filters.status ?? null, search: filters.search ?? '' },
      )
      .pipe(
        map(({ data, meta }) => ({
          lines: data,
          totals: meta as unknown as ContributionTotals,
        })),
      );
  }

  paymentsOfCycle(cycleId: string): Observable<ContributionPayment[]> {
    return this.api.get<ContributionPayment[]>(`/cycles/${cycleId}/contributions`);
  }

  paymentsOfTontine(tontineId: string): Observable<ContributionPayment[]> {
    return this.api.get<ContributionPayment[]>(`/tontines/${tontineId}/contributions`);
  }
}

@Injectable({ providedIn: 'root' })
export class PaymentService {
  private readonly api = inject(ApiClient);

  record(tontineId: string, payload: PaymentPayload): Observable<ContributionPayment> {
    return this.api.post<ContributionPayment>(
      `/tontines/${tontineId}/contributions`,
      payload,
    );
  }

  confirm(paymentId: string): Observable<ContributionPayment> {
    return this.api.post<ContributionPayment>(`/contributions/${paymentId}/confirm`);
  }

  reject(paymentId: string, reason: string): Observable<ContributionPayment> {
    return this.api.post<ContributionPayment>(`/contributions/${paymentId}/reject`, {
      reason,
    });
  }

  cancel(paymentId: string, reason: string): Observable<ContributionPayment> {
    return this.api.post<ContributionPayment>(`/contributions/${paymentId}/cancel`, {
      reason,
    });
  }

  uploadProof(file: File): Observable<Attachment> {
    return this.api.upload<Attachment>('/attachments', file);
  }
}

@Injectable({ providedIn: 'root' })
export class DrawService {
  private readonly api = inject(ApiClient);

  eligibility(tontineId: string, cycleId: string): Observable<DrawEligibility> {
    return this.api.get<DrawEligibility>(
      `/tontines/${tontineId}/cycles/${cycleId}/draw-eligibility`,
    );
  }

  /** Le gagnant est choisi par le serveur : rien n'est envoyé à ce sujet. */
  run(
    tontineId: string,
    cycleId: string,
    override?: { reason: string },
  ): Observable<DrawSession> {
    return this.api.post<DrawSession>(`/tontines/${tontineId}/draws`, {
      cycleId,
      override: Boolean(override),
      overrideReason: override?.reason ?? null,
    });
  }

  history(tontineId: string): Observable<DrawSession[]> {
    return this.api.get<DrawSession[]>(`/tontines/${tontineId}/draws`);
  }

  byId(drawId: string): Observable<DrawSession> {
    return this.api.get<DrawSession>(`/draws/${drawId}`);
  }

  invalidate(drawId: string, reason: string): Observable<DrawSession> {
    return this.api.post<DrawSession>(`/draws/${drawId}/invalidate`, { reason });
  }
}

@Injectable({ providedIn: 'root' })
export class BeneficiaryService {
  private readonly api = inject(ApiClient);

  forTontine(tontineId: string): Observable<Beneficiary[]> {
    return this.api.get<Beneficiary[]>(`/tontines/${tontineId}/beneficiaries`);
  }

  ofCycle(cycleId: string): Observable<Beneficiary | null> {
    return this.api.get<Beneficiary | null>(`/cycles/${cycleId}/beneficiary`);
  }
}

@Injectable({ providedIn: 'root' })
export class PayoutService {
  private readonly api = inject(ApiClient);

  forTontine(tontineId: string): Observable<Payout[]> {
    return this.api.get<Payout[]>(`/tontines/${tontineId}/payouts`);
  }

  record(payload: PayoutPayload): Observable<Payout> {
    return this.api.post<Payout>('/payouts', payload);
  }

  confirm(payoutId: string): Observable<Payout> {
    return this.api.post<Payout>(`/payouts/${payoutId}/confirm`);
  }

  fail(payoutId: string, reason: string): Observable<Payout> {
    return this.api.post<Payout>(`/payouts/${payoutId}/fail`, { reason });
  }
}

@Injectable({ providedIn: 'root' })
export class TreasuryService {
  private readonly api = inject(ApiClient);

  snapshot(organizationId: string): Observable<TreasurySnapshot> {
    return this.api.get<TreasurySnapshot>(`/organizations/${organizationId}/treasury`);
  }

  report(organizationId: string): Observable<ReportSnapshot> {
    return this.api.get<ReportSnapshot>(`/organizations/${organizationId}/reports`);
  }

  recordTransaction(
    organizationId: string,
    payload: {
      type: TransactionType;
      category: string;
      amount: number;
      description?: string | null;
    },
  ): Observable<CashTransaction> {
    return this.api.post<CashTransaction>(
      `/organizations/${organizationId}/transactions`,
      payload,
    );
  }
}

@Injectable({ providedIn: 'root' })
export class AuditService {
  private readonly api = inject(ApiClient);

  list(
    organizationId: string,
    filters: { tontineId?: string | null; actions?: string | null; limit?: number } = {},
  ): Observable<AuditLog[]> {
    return this.api.get<AuditLog[]>(`/organizations/${organizationId}/audit-logs`, {
      tontineId: filters.tontineId ?? null,
      actions: filters.actions ?? null,
      limit: filters.limit ?? 100,
    });
  }
}

@Injectable({ providedIn: 'root' })
export class NotificationService {
  private readonly api = inject(ApiClient);

  list(organizationId?: string | null): Observable<AppNotification[]> {
    return this.api.get<AppNotification[]>('/notifications', {
      organizationId: organizationId ?? null,
    });
  }

  unreadCount(): Observable<number> {
    return this.api
      .get<{ count: number }>('/notifications/unread-count')
      .pipe(map((body) => body.count));
  }

  markAllRead(): Observable<number> {
    return this.api
      .post<{ updated: number }>('/notifications/read-all')
      .pipe(map((body) => body.updated));
  }

  markRead(id: string): Observable<boolean> {
    return this.api
      .post<{ read: boolean }>(`/notifications/${id}/read`)
      .pipe(map((body) => body.read));
  }
}

@Injectable({ providedIn: 'root' })
export class ReminderService {
  private readonly api = inject(ApiClient);

  targets(organizationId: string, tontineId?: string | null): Observable<ReminderTarget[]> {
    return this.api.get<ReminderTarget[]>(
      `/organizations/${organizationId}/reminder-targets`,
      { tontineId: tontineId ?? null },
    );
  }
}
