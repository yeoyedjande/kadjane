import { CommonModule } from '@angular/common';
import { Component, effect, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import { Organization } from '../../core/models/domain.models';
import { OrganizationService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService } from '../../core/services/toast.service';
import { PageHeader, StateView } from '../../shared/ui.components';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, PageHeader, StateView],
  template: `
    <k-page-header
      title="Paramètres de l'organisation"
      [subtitle]="session.organization()?.name ?? null"
    />

    <k-state [loading]="loading()" [error]="null" />

    @if (session.organization(); as organization) {
      <form class="k-stack" [formGroup]="form" (ngSubmit)="submit()">
        <article class="k-card">
          <div class="k-card__header"><h2 class="k-card__title">Identité</h2></div>
          <div class="k-card__body k-stack">
            <div class="k-grid k-grid--2">
              <label class="k-field">
                <span class="k-label">Nom</span>
                <input class="k-input" formControlName="name" />
              </label>
              <label class="k-field">
                <span class="k-label">Logo (URL)</span>
                <input class="k-input" formControlName="logoUrl" placeholder="https://…" />
              </label>
            </div>

            <label class="k-field">
              <span class="k-label">Description</span>
              <textarea class="k-textarea" rows="2" formControlName="description"></textarea>
            </label>

            <div class="k-grid k-grid--3">
              <label class="k-field">
                <span class="k-label">Pays</span>
                <input class="k-input" maxlength="2" formControlName="country" />
              </label>
              <label class="k-field">
                <span class="k-label">Devise</span>
                <input class="k-input" maxlength="3" formControlName="currency" />
              </label>
              <label class="k-field">
                <span class="k-label">Téléphone</span>
                <input class="k-input" formControlName="phone" />
              </label>
            </div>

            <div class="k-grid k-grid--2">
              <label class="k-field">
                <span class="k-label">E-mail</span>
                <input class="k-input" type="email" formControlName="email" />
              </label>
              <label class="k-field">
                <span class="k-label">Adresse</span>
                <input class="k-input" formControlName="address" />
              </label>
            </div>

            <label class="k-field">
              <span class="k-label">Règlement général</span>
              <textarea class="k-textarea" rows="3" formControlName="rules"></textarea>
            </label>
          </div>
        </article>

        <article class="k-card">
          <div class="k-card__header">
            <h2 class="k-card__title">Règles de fonctionnement</h2>
          </div>
          <div class="k-card__body k-stack" formGroupName="settings">
            <label class="rule">
              <input type="checkbox" formControlName="requireFullPaymentBeforeDraw" />
              <span>
                <strong>Exiger toutes les cotisations avant le tirage</strong>
                <small class="k-muted">
                  Valeur par défaut appliquée aux nouvelles tontines.
                </small>
              </span>
            </label>

            <label class="rule">
              <input type="checkbox" formControlName="allowDrawOverride" />
              <span>
                <strong>Autoriser le forçage du tirage</strong>
                <small class="k-muted">
                  Toujours avec justification obligatoire et trace d'audit.
                </small>
              </span>
            </label>

            <div class="k-grid k-grid--2">
              <label class="k-field">
                <span class="k-label">Tolérance de retard (jours)</span>
                <input
                  class="k-input"
                  type="number"
                  min="0"
                  max="30"
                  formControlName="latePaymentGraceDays"
                />
              </label>
              <label class="k-field">
                <span class="k-label">Rappel avant échéance (jours)</span>
                <input
                  class="k-input"
                  type="number"
                  min="0"
                  max="30"
                  formControlName="notifyBeforeDueDays"
                />
              </label>
            </div>
          </div>
        </article>

        <div class="k-row" style="justify-content: flex-end">
          @if (!canEdit()) {
            <span class="k-hint" style="margin-right: auto">
              Votre rôle ne permet pas de modifier ces paramètres.
            </span>
          }
          <button type="submit" class="k-btn" [disabled]="saving() || !canEdit()">
            {{ saving() ? 'Enregistrement…' : 'Enregistrer' }}
          </button>
        </div>
      </form>
    }
  `,
  styles: [
    `
      .rule {
        display: flex;
        align-items: flex-start;
        gap: 12px;
        padding: 14px 16px;
        border: 1px solid var(--k-outline);
        border-radius: var(--k-radius);
        cursor: pointer;
      }
      .rule span {
        display: flex;
        flex-direction: column;
        gap: 3px;
      }
    `,
  ],
})
export class SettingsPage {
  private readonly organizations = inject(OrganizationService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly loading = signal(false);
  readonly saving = signal(false);

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    description: [''],
    logoUrl: [''],
    country: ['CI', Validators.required],
    currency: ['XOF', Validators.required],
    phone: [''],
    email: [''],
    address: [''],
    rules: [''],
    settings: this.fb.nonNullable.group({
      requireFullPaymentBeforeDraw: [true],
      allowDrawOverride: [true],
      latePaymentGraceDays: [3],
      notifyBeforeDueDays: [3],
    }),
  });

  constructor() {
    // Le formulaire suit l'organisation active, y compris après un changement.
    effect(() => {
      const organization = this.session.organization();
      if (organization) {
        this.fill(organization);
      }
    });
  }

  canEdit(): boolean {
    return this.session.can('organization.edit');
  }

  private fill(organization: Organization): void {
    this.form.reset({
      name: organization.name,
      description: organization.description ?? '',
      logoUrl: organization.logoUrl ?? '',
      country: organization.country,
      currency: organization.currency,
      phone: organization.phone ?? '',
      email: organization.email ?? '',
      address: organization.address ?? '',
      rules: organization.rules ?? '',
      settings: { ...organization.settings },
    });
    if (!this.canEdit()) {
      this.form.disable({ emitEvent: false });
    }
  }

  submit(): void {
    const organization = this.session.organization();
    if (!organization || this.form.invalid || this.saving()) {
      this.form.markAllAsTouched();
      return;
    }
    this.saving.set(true);
    const raw = this.form.getRawValue();

    this.organizations
      .update(organization.id, {
        name: raw.name.trim(),
        description: raw.description.trim() || null,
        logoUrl: raw.logoUrl.trim() || null,
        country: raw.country.toUpperCase(),
        currency: raw.currency.toUpperCase(),
        phone: raw.phone.trim() || null,
        email: raw.email.trim() || null,
        address: raw.address.trim() || null,
        rules: raw.rules.trim() || null,
        settings: raw.settings,
      })
      .subscribe({
        next: (updated) => {
          this.saving.set(false);
          this.session.replace(updated);
          this.toast.success('Paramètres enregistrés.');
        },
        error: (error: unknown) => {
          this.saving.set(false);
          this.toast.fromError(error);
        },
      });
  }
}
