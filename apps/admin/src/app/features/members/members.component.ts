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
  readonly deleting = signal<string | null>(null);

  private pendingChange: (() => void) | null = null;

  readonly form = this.fb.nonNullable.group({
    firstName: ['', [Validators.required, Validators.minLength(2)]],
    lastName: ['', [Validators.required, Validators.minLength(2)]],
    phone: ['', [Validators.required, Validators.minLength(6)]],
    email: [''],
    // Facultatif : vide, le backend génère un mot de passe et le renvoie.
    password: ['', Validators.minLength(8)],
    role: ['member' as OrgRole, Validators.required],
    status: ['active' as MemberStatus, Validators.required],
  });

  /** Accès à remettre au membre, affichés juste après sa création. */
  readonly credentials = signal<{
    name: string;
    phone: string;
    password: string;
  } | null>(null);
  readonly copied = signal(false);

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

  /** Texte prêt à être collé dans un message au membre. */
  credentialsMessage(): string {
    const access = this.credentials();
    if (!access) {
      return '';
    }
    return [
      `Bonjour ${access.name},`,
      'Votre accès à Kadjane :',
      `Identifiant : ${access.phone}`,
      `Mot de passe : ${access.password}`,
      'Vous pourrez le modifier depuis l’application.',
    ].join('\n');
  }

  async copyCredentials(): Promise<void> {
    try {
      await navigator.clipboard.writeText(this.credentialsMessage());
      this.copied.set(true);
    } catch {
      // Presse-papiers refusé (contexte non sécurisé, permission) : le texte
      // reste visible et sélectionnable à l'écran.
      this.toast.info('Copie impossible : sélectionnez le texte manuellement.');
    }
  }

  dismissCredentials(): void {
    this.credentials.set(null);
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
    const payload: MemberPayload = {
      firstName: raw.firstName.trim(),
      lastName: raw.lastName.trim(),
      phone: raw.phone.trim(),
      email: raw.email.trim() || null,
      role: raw.role,
      status: raw.status,
    };
    // Le mot de passe n'a de sens qu'à la création : une modification ne doit
    // jamais réinitialiser l'accès d'un membre à son insu.
    if (!this.editing() && raw.password.trim()) {
      payload.password = raw.password.trim();
    }

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

  /** Demande confirmation avant de retirer un membre.
   *
   *  La suppression est définitive et rend l'accès mobile impossible : elle
   *  passe donc toujours par le dialogue, jamais par un clic isolé.
   */
  askDelete(member: Member): void {
    const organizationId = this.session.organizationId();
    if (!organizationId) {
      return;
    }
    const name = `${member.user.firstName} ${member.user.lastName}`;
    this.pendingChange = () => this.remove(organizationId, member, name);
    this.confirm.set({
      title: 'Supprimer ce membre',
      message: `${name} sera retiré de l'organisation et perdra l'accès à l'application mobile. Cette action est définitive.`,
      confirmLabel: 'Supprimer',
    });
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

  private remove(organizationId: string, member: Member, name: string): void {
    this.deleting.set(member.id);
    this.members.remove(organizationId, member.id).subscribe({
      next: () => {
        this.deleting.set(null);
        this.toast.success(`${name} a été supprimé.`);
        this.load();
      },
      error: (error: unknown) => {
        this.deleting.set(null);
        // `member_has_history` n'est pas un échec technique mais une règle
        // métier : le message du backend indique déjà la désactivation.
        this.toast.fromError(error);
      },
    });
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
        if (!existing) {
          // Le mot de passe généré n'est lisible qu'ici : la base n'en garde
          // qu'une empreinte. On l'affiche pour que l'admin le transmette.
          const password = member.temporaryPassword ?? payload.password ?? null;
          if (password) {
            this.credentials.set({
              name: `${member.user.firstName} ${member.user.lastName}`,
              phone: member.user.phone,
              password,
            });
            this.copied.set(false);
          }
        }
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
