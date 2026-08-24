import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';

import {
  CampaignEntry,
  CampaignPayload,
  CampaignPaymentPayload,
  CampaignPaymentRecord,
  CampaignStatus,
  Cashbox,
  CashboxPayload,
  CashboxTransaction,
  CashTransactionPayload,
  ContributionCampaign,
  ContributionType,
  FinancialDashboard,
  Permission,
  Role,
  RolePayload,
  RoleStatus,
} from '../models/domain.models';
import { ApiClient } from './api-client.service';

/** Services de la phase 7 : RBAC administrable, caisses, cotisations.
 *
 *  Même règle que `domain.services.ts` : les écrans ne construisent jamais
 *  d'URL, et aucun montant n'est recalculé côté client — les soldes et les
 *  taux de recouvrement viennent du backend, qui seul connaît le journal.
 */

@Injectable({ providedIn: 'root' })
export class RbacService {
  private readonly api = inject(ApiClient);

  /** Catalogue global : il décrit le produit, pas une organisation. */
  catalog(): Observable<{ permissions: Permission[]; categories: string[] }> {
    return this.api
      .getWithMeta<Permission[]>('/permissions')
      .pipe(
        map((body) => ({
          permissions: body.data,
          categories: (body.meta['categories'] as string[]) ?? [],
        })),
      );
  }

  roles(organizationId: string): Observable<Role[]> {
    return this.api.get<Role[]>(`/organizations/${organizationId}/roles`);
  }

  create(organizationId: string, payload: RolePayload): Observable<Role> {
    return this.api.post<Role>(`/organizations/${organizationId}/roles`, payload);
  }

  update(
    organizationId: string,
    roleId: string,
    changes: { name?: string; description?: string; status?: RoleStatus },
  ): Observable<Role> {
    return this.api.patch<Role>(
      `/organizations/${organizationId}/roles/${roleId}`,
      changes,
    );
  }

  /** Remplacement intégral : la console envoie l'état des cases cochées.
   *
   *  Un delta fusionnerait silencieusement les intentions de deux
   *  administrateurs qui enregistrent en même temps.
   */
  setPermissions(
    organizationId: string,
    roleId: string,
    permissions: string[],
  ): Observable<Role> {
    return this.api.put<Role>(
      `/organizations/${organizationId}/roles/${roleId}/permissions`,
      { permissions },
    );
  }

  assign(
    organizationId: string,
    memberId: string,
    roleId: string,
  ): Observable<{ memberId: string; role: string; permissions: string[] }> {
    return this.api.patch(
      `/organizations/${organizationId}/members/${memberId}/role`,
      { roleId },
    );
  }
}

@Injectable({ providedIn: 'root' })
export class CashboxService {
  private readonly api = inject(ApiClient);

  list(organizationId: string): Observable<Cashbox[]> {
    return this.api.get<Cashbox[]>(`/organizations/${organizationId}/cashboxes`);
  }

  create(organizationId: string, payload: CashboxPayload): Observable<Cashbox> {
    return this.api.post<Cashbox>(
      `/organizations/${organizationId}/cashboxes`,
      payload,
    );
  }

  byId(cashboxId: string): Observable<Cashbox> {
    return this.api.get<Cashbox>(`/cashboxes/${cashboxId}`);
  }

  update(cashboxId: string, changes: Partial<CashboxPayload>): Observable<Cashbox> {
    return this.api.patch<Cashbox>(`/cashboxes/${cashboxId}`, changes);
  }

  close(cashboxId: string): Observable<Cashbox> {
    return this.api.post<Cashbox>(`/cashboxes/${cashboxId}/close`);
  }

  transactions(
    cashboxId: string,
    query: { limit?: number; offset?: number } = {},
  ): Observable<{ items: CashboxTransaction[]; total: number }> {
    return this.api
      .getWithMeta<CashboxTransaction[]>(`/cashboxes/${cashboxId}/transactions`, {
        limit: query.limit ?? 50,
        offset: query.offset ?? 0,
      })
      .pipe(
        map((body) => ({
          items: body.data,
          total: (body.meta['total'] as number) ?? body.data.length,
        })),
      );
  }

  record(
    cashboxId: string,
    payload: CashTransactionPayload,
  ): Observable<CashboxTransaction> {
    return this.api.post<CashboxTransaction>(
      `/cashboxes/${cashboxId}/transactions`,
      payload,
    );
  }

  /** L'écriture sort du solde, pas du journal. */
  cancelTransaction(
    transactionId: string,
    reason: string,
    reversed = false,
  ): Observable<CashboxTransaction> {
    return this.api.post<CashboxTransaction>(
      `/cash-transactions/${transactionId}/cancel`,
      { reason, reversed },
    );
  }
}

@Injectable({ providedIn: 'root' })
export class CampaignService {
  private readonly api = inject(ApiClient);

  list(
    organizationId: string,
    query: {
      type?: ContributionType | null;
      status?: CampaignStatus | null;
      cashboxId?: string | null;
      limit?: number;
      offset?: number;
    } = {},
  ): Observable<{ items: ContributionCampaign[]; total: number }> {
    return this.api
      .getWithMeta<ContributionCampaign[]>(
        `/organizations/${organizationId}/contribution-campaigns`,
        {
          type: query.type ?? null,
          status: query.status ?? null,
          cashboxId: query.cashboxId ?? null,
          limit: query.limit ?? 50,
          offset: query.offset ?? 0,
        },
      )
      .pipe(
        map((body) => ({
          items: body.data,
          total: (body.meta['total'] as number) ?? body.data.length,
        })),
      );
  }

  create(
    organizationId: string,
    payload: CampaignPayload,
  ): Observable<ContributionCampaign> {
    return this.api.post<ContributionCampaign>(
      `/organizations/${organizationId}/contribution-campaigns`,
      payload,
    );
  }

  byId(campaignId: string): Observable<ContributionCampaign> {
    return this.api.get<ContributionCampaign>(
      `/contribution-campaigns/${campaignId}`,
    );
  }

  close(campaignId: string): Observable<ContributionCampaign> {
    return this.api.patch<ContributionCampaign>(
      `/contribution-campaigns/${campaignId}`,
      { status: 'closed' },
    );
  }

  entry(entryId: string): Observable<CampaignEntry> {
    return this.api.get<CampaignEntry>(`/contribution-entries/${entryId}`);
  }

  /** Une saisie, sept effets — le backend les enchaîne en une transaction. */
  pay(
    entryId: string,
    payload: CampaignPaymentPayload,
  ): Observable<{ payment: CampaignPaymentRecord; entry: CampaignEntry }> {
    return this.api.post(`/contribution-entries/${entryId}/payments`, payload);
  }

  exempt(entryId: string, reason: string): Observable<CampaignEntry> {
    return this.api.post<CampaignEntry>(
      `/contribution-entries/${entryId}/exempt`,
      { reason },
    );
  }

  cancelPayment(
    paymentId: string,
    reason: string,
  ): Observable<{ payment: CampaignPaymentRecord; entry: CampaignEntry }> {
    return this.api.post(`/contribution-payments/${paymentId}/cancel`, { reason });
  }

  unpaid(
    organizationId: string,
    query: { limit?: number; offset?: number } = {},
  ): Observable<{ items: CampaignEntry[]; total: number }> {
    return this.api
      .getWithMeta<CampaignEntry[]>(`/organizations/${organizationId}/unpaid`, {
        limit: query.limit ?? 100,
        offset: query.offset ?? 0,
      })
      .pipe(
        map((body) => ({
          items: body.data,
          total: (body.meta['total'] as number) ?? body.data.length,
        })),
      );
  }

  dashboard(organizationId: string): Observable<FinancialDashboard> {
    return this.api.get<FinancialDashboard>(
      `/organizations/${organizationId}/financial-dashboard`,
    );
  }
}
