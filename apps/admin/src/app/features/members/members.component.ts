import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import { ApiError } from '../../core/models/api.models';
import {
  Member,
  MemberPayload,
  MemberStatus,
  OrgRole,
} from '../../core/models/domain.models';
import { FrDatePipe, LabelPipe } from '../../core/pipes/format.pipes';
import { MemberService } from '../../core/services/domain.services';
import { SessionService } from '../../core/services/session.service';
import { ToastService, describeError } from '../../core/services/toast.service';
import {
  ConfirmDialog,
  ConfirmRequest,
  PageHeader,
  Pagination,
  SearchInput,
  StateView,
  StatusBadge,
  UserAvatar,
} from '../../shared/ui.components';

const ROLES: OrgRole[] = [
  'admin',
  'president',
  'treasurer',
  'auditor',
  'member',
];

const STATUSES: MemberStatus[] = ['active', 'inactive', 'suspended', 'pending'];

@Component({
  selector: 'app-members',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FrDatePipe,
    LabelPipe,
    PageHeader,
    Pagination,
    SearchInput,
    StateView,
    StatusBadge,
    UserAvatar,
    ConfirmDialog,
  ],
  templateUrl: './members.component.html',
})
export class MembersPage {
  private readonly members = inject(MemberService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  readonly session = inject(SessionService);

  readonly roles = ROLES;
  readonly statuses = STATUSES;

  readonly rows = signal<Member[]>([]);
  readonly total = signal(0);
  readonly hasMore = signal(false);
  readonly page = signal(0);
  readonly search = signal('');
  readonly role = signal<OrgRole | null>(null);
  readonly status = signal<MemberStatus | null>(null);

  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly formOpen = signal(false);
  readonly editing = signal<Member | null>(null);
  readonly confirm = signal<ConfirmRequest | null>(null);

  private pendingChange: (() => void) | null = null;

  readonly form = this.fb.nonNullable.group({
    firstName: ['', [Validators.required, Validators.minLength(2)]],
    lastName: ['', [Validators.required, Validators.minLength(2)]],
    phone: ['', [Validators.required, Validators.minLength(6)]],
    email: [''],
    role: ['member' as OrgRole, Validators.required],
    status: ['active' as MemberStatus, Validators.required],
  });

  constructor() {
    this.load();
  }

  load(): void {
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      this.loading.set(false);
      return;
    }
    this.loading.set(true);
    this.error.set(null);
    this.members
      .list(organizationId, {
        page: this.page(),
        pageSize: 20,
        query: this.search(),
        role: this.role(),
        status: this.status(),
      })
      .subscribe({
        next: (result) => {
          this.rows.set(result.items);
          this.total.set(result.total);
          this.hasMore.set(result.hasMore);
          this.loading.set(false);
        },
        error: (error: unknown) => {
          this.error.set(describeError(error));
          this.loading.set(false);
        },
      });
  }

  onSearch(value: string): void {
    this.search.set(value);
    this.page.set(0);
    this.load();
  }

  onFilter(kind: 'role' | 'status', value: string): void {
    if (kind === 'role') {
      this.role.set((value || null) as OrgRole | null);
    } else {
      this.status.set((value || null) as MemberStatus | null);
    }
    this.page.set(0);
    this.load();
  }

  goToPage(page: number): void {
    this.page.set(Math.max(0, page));
    this.load();
  }

  openCreate(): void {
    this.editing.set(null);
    this.form.reset({ role: 'member', status: 'active' });
    this.form.controls.phone.enable();
    this.formOpen.set(true);
  }

  openEdit(member: Member): void {
    this.editing.set(member);
    this.form.reset({
      firstName: member.user.firstName,
      lastName: member.user.lastName,
      phone: member.user.phone,
      email: member.user.email ?? '',
      role: member.role,
      status: member.status,
    });
    this.formOpen.set(true);
  }

  submit(): void {
    if (this.form.invalid || this.saving()) {
      this.form.markAllAsTouched();
      return;
    }
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }

    const raw = this.form.getRawValue();
    const payload = {
      firstName: raw.firstName.trim(),
      lastName: raw.lastName.trim(),
      phone: raw.phone.trim(),
      email: raw.email.trim() || null,
      role: raw.role,
      status: raw.status,
    };

    const existing = this.editing();
    // Un changement de rôle ou de statut engage l'organisation : on confirme.
    if (
      existing &&
      (existing.role !== payload.role || existing.status !== payload.status)
    ) {
      this.pendingChange = () => this.persist(organizationId, payload);
      this.confirm.set({
        title: 'Confirmer la modification',
        message: `Le rôle ou le statut de ${payload.firstName} ${payload.lastName} va changer. Cette modification est immédiatement visible dans l'application mobile.`,
        confirmLabel: 'Modifier',
      });
      return;
    }

    this.persist(organizationId, payload);
  }

  onConfirmed(): void {
    const action = this.pendingChange;
    this.pendingChange = null;
    this.confirm.set(null);
    action?.();
  }

  onCancelled(): void {
    this.pendingChange = null;
    this.confirm.set(null);
  }

  private persist(organizationId: string, payload: MemberPayload): void {
    this.saving.set(true);
    const existing = this.editing();
    const request$ = existing
      ? this.members.update(organizationId, existing.id, payload)
      : this.members.create(organizationId, payload);

    request$.subscribe({
      next: (member) => {
        this.saving.set(false);
        this.formOpen.set(false);
        this.toast.success(
          existing
            ? `${member.user.firstName} ${member.user.lastName} a été mis à jour.`
            : `${member.user.firstName} ${member.user.lastName} a été ajouté.`,
        );
        this.page.set(0);
        this.load();
      },
      error: (error: unknown) => {
        this.saving.set(false);
        this.applyFieldErrors(error);
        this.toast.fromError(error);
      },
    });
  }

  /** Reporte les erreurs de validation du backend sur les champs. */
  private applyFieldErrors(error: unknown): void {
    if (!(error instanceof ApiError)) {
      return;
    }
    for (const [field, message] of Object.entries(error.fieldErrors)) {
      const name = field.split('.').pop() ?? field;
      const control = (this.form.controls as Record<string, unknown>)[name];
      if (control && typeof control === 'object' && 'setErrors' in control) {
        (control as { setErrors: (errors: Record<string, string>) => void }).setErrors({
          server: message,
        });
      }
    }
  }

  invalid(control: string): boolean {
    const field = (this.form.controls as Record<string, any>)[control];
    return field?.invalid && (field.touched || field.dirty);
  }

  serverError(control: string): string | null {
    const field = (this.form.controls as Record<string, any>)[control];
    return field?.errors?.['server'] ?? null;
  }
}
