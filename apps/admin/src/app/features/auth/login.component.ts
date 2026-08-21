import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { switchMap } from 'rxjs';

import { AuthService } from '../../core/services/auth.service';
import { SessionService } from '../../core/services/session.service';
import { describeError } from '../../core/services/toast.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss',
})
export class LoginPage {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  readonly form = this.fb.nonNullable.group({
    identifier: ['', [Validators.required, Validators.minLength(3)]],
    password: ['', [Validators.required, Validators.minLength(4)]],
  });

  submit(): void {
    if (this.form.invalid || this.loading()) {
      this.form.markAllAsTouched();
      return;
    }

    this.loading.set(true);
    this.error.set(null);

    const { identifier, password } = this.form.getRawValue();
    this.auth
      .login(identifier.trim(), password)
      .pipe(switchMap(() => this.session.load()))
      .subscribe({
        next: (organization) => {
          this.loading.set(false);
          if (!organization) {
            this.error.set(
              "Votre compte n'est rattaché à aucune organisation.",
            );
            this.auth.clear();
            return;
          }
          const redirect =
            this.route.snapshot.queryParamMap.get('redirect') ?? '/dashboard';
          void this.router.navigateByUrl(redirect);
        },
        error: (error: unknown) => {
          this.loading.set(false);
          this.error.set(describeError(error, 'Connexion impossible.'));
        },
      });
  }

  invalid(control: 'identifier' | 'password'): boolean {
    const field = this.form.controls[control];
    return field.invalid && (field.touched || field.dirty);
  }
}
