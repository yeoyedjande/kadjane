import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { ToastService } from './core/services/toast.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  template: `
    <router-outlet />

    <div class="toasts">
      @for (toast of toasts.toasts(); track toast.id) {
        <div class="toast" [class]="'toast--' + toast.kind" (click)="toasts.dismiss(toast.id)">
          {{ toast.message }}
        </div>
      }
    </div>
  `,
  styles: [
    `
      .toasts {
        position: fixed;
        top: 16px;
        right: 16px;
        z-index: 100;
        display: flex;
        flex-direction: column;
        gap: 10px;
        max-width: 380px;
      }
      .toast {
        padding: 12px 16px;
        border-radius: var(--k-radius-sm);
        border-left: 4px solid;
        background: var(--k-surface);
        box-shadow: var(--k-shadow);
        font-size: 13.5px;
        cursor: pointer;
        animation: slide 0.2s ease;
      }
      .toast--success {
        border-color: var(--k-success);
      }
      .toast--error {
        border-color: var(--k-danger);
      }
      .toast--info {
        border-color: var(--k-info);
      }
      @keyframes slide {
        from {
          opacity: 0;
          transform: translateX(12px);
        }
      }
    `,
  ],
})
export class App {
  readonly toasts = inject(ToastService);
}
