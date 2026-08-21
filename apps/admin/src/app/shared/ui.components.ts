import { CommonModule } from '@angular/common';
import {
  Component,
  EventEmitter,
  Input,
  Output,
  computed,
  input,
  signal,
} from '@angular/core';
import { FormsModule } from '@angular/forms';

import { LabelPipe } from '../core/pipes/format.pipes';

/** Bibliothèque de composants du back-office.
 *
 *  Ils sont regroupés ici parce qu'ils sont courts et toujours utilisés
 *  ensemble : un fichier par composant aurait multiplié les imports sans rien
 *  clarifier.
 */

type BadgeTone = 'neutral' | 'success' | 'warning' | 'danger' | 'info' | 'gold';

const TONES: Record<string, BadgeTone> = {
  active: 'success',
  paid: 'success',
  confirmed: 'success',
  completed: 'success',
  paid_out: 'success',
  ready_for_draw: 'gold',
  drawn: 'gold',
  designated: 'gold',
  collecting: 'info',
  processing: 'info',
  upcoming: 'neutral',
  pending: 'warning',
  partial: 'warning',
  payout_pending: 'warning',
  due_today: 'warning',
  draft: 'neutral',
  closed: 'neutral',
  inactive: 'neutral',
  archived: 'neutral',
  scheduled: 'info',
  late: 'danger',
  escalated: 'danger',
  suspended: 'danger',
  cancelled: 'danger',
  rejected: 'danger',
  failed: 'danger',
  invalidated: 'danger',
};

@Component({
  selector: 'k-badge',
  standalone: true,
  imports: [CommonModule, LabelPipe],
  template: `<span class="badge" [class]="'badge--' + tone()">{{
    value() | label
  }}</span>`,
  styles: [
    `
      .badge {
        display: inline-flex;
        align-items: center;
        padding: 3px 10px;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 650;
        white-space: nowrap;
      }
      .badge--neutral {
        background: var(--k-surface-muted);
        color: var(--k-text-secondary);
      }
      .badge--success {
        background: var(--k-success-surface);
        color: var(--k-success);
      }
      .badge--warning {
        background: var(--k-warning-surface);
        color: var(--k-warning);
      }
      .badge--danger {
        background: var(--k-danger-surface);
        color: var(--k-danger);
      }
      .badge--info {
        background: var(--k-info-surface);
        color: var(--k-info);
      }
      .badge--gold {
        background: var(--k-gold-container);
        color: #8a6011;
      }
    `,
  ],
})
export class StatusBadge {
  readonly value = input.required<string>();
  readonly tone = computed<BadgeTone>(() => TONES[this.value()] ?? 'neutral');
}

@Component({
  selector: 'k-page-header',
  standalone: true,
  imports: [CommonModule],
  template: `
    <header class="head">
      <div>
        <h1>{{ title() }}</h1>
        @if (subtitle()) {
          <p class="sub">{{ subtitle() }}</p>
        }
      </div>
      <div class="actions"><ng-content /></div>
    </header>
  `,
  styles: [
    `
      .head {
        display: flex;
        flex-wrap: wrap;
        align-items: flex-start;
        justify-content: space-between;
        gap: 16px;
        margin-bottom: 20px;
      }
      .sub {
        margin: 4px 0 0;
        color: var(--k-text-secondary);
      }
      .actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
      }
    `,
  ],
})
export class PageHeader {
  readonly title = input.required<string>();
  readonly subtitle = input<string | null>(null);
}

@Component({
  selector: 'k-state',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (loading()) {
      <div class="state">
        <span class="spinner"></span>
        <p>Chargement…</p>
      </div>
    } @else if (error()) {
      <div class="state state--error">
        <p class="title">{{ error() }}</p>
        @if (retryable()) {
          <button type="button" class="k-btn k-btn--ghost k-btn--sm" (click)="retry.emit()">
            Réessayer
          </button>
        }
      </div>
    } @else if (empty()) {
      <div class="state">
        <p class="title">{{ emptyTitle() }}</p>
        @if (emptyHint()) {
          <p class="hint">{{ emptyHint() }}</p>
        }
        <ng-content />
      </div>
    }
  `,
  styles: [
    `
      .state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 10px;
        padding: 48px 24px;
        color: var(--k-text-secondary);
        text-align: center;
      }
      .state--error {
        color: var(--k-danger);
      }
      .title {
        margin: 0;
        font-weight: 600;
      }
      .hint {
        margin: 0;
        font-size: 13px;
        color: var(--k-text-tertiary);
      }
      .spinner {
        width: 22px;
        height: 22px;
        border: 2px solid var(--k-outline);
        border-top-color: var(--k-primary);
        border-radius: 50%;
        animation: spin 0.7s linear infinite;
      }
      @keyframes spin {
        to {
          transform: rotate(360deg);
        }
      }
    `,
  ],
})
export class StateView {
  readonly loading = input(false);
  readonly error = input<string | null>(null);
  readonly empty = input(false);
  readonly emptyTitle = input('Aucune donnée');
  readonly emptyHint = input<string | null>(null);
  readonly retryable = input(true);
  @Output() readonly retry = new EventEmitter<void>();
}

@Component({
  selector: 'k-search',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <label class="wrap">
      <span class="icon">⌕</span>
      <input
        type="search"
        class="k-input"
        [placeholder]="placeholder()"
        [ngModel]="value()"
        (ngModelChange)="onInput($event)"
      />
    </label>
  `,
  styles: [
    `
      .wrap {
        position: relative;
        display: block;
        min-width: 220px;
      }
      .icon {
        position: absolute;
        top: 50%;
        left: 10px;
        transform: translateY(-50%);
        color: var(--k-text-tertiary);
        font-size: 16px;
      }
      input {
        padding-left: 30px;
      }
    `,
  ],
})
export class SearchInput {
  readonly placeholder = input('Rechercher…');
  readonly value = input('');
  @Output() readonly search = new EventEmitter<string>();

  private timer: ReturnType<typeof setTimeout> | null = null;

  /** Anti-rebond : on n'interroge pas l'API à chaque frappe. */
  onInput(value: string): void {
    if (this.timer) {
      clearTimeout(this.timer);
    }
    this.timer = setTimeout(() => this.search.emit(value), 300);
  }
}

@Component({
  selector: 'k-pagination',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="pager">
      <span class="count">
        {{ from() }}–{{ to() }} sur {{ total() }}
      </span>
      <div class="k-row">
        <button
          type="button"
          class="k-btn k-btn--ghost k-btn--sm"
          [disabled]="page() === 0"
          (click)="go.emit(page() - 1)"
        >
          Précédent
        </button>
        <button
          type="button"
          class="k-btn k-btn--ghost k-btn--sm"
          [disabled]="!hasMore()"
          (click)="go.emit(page() + 1)"
        >
          Suivant
        </button>
      </div>
    </div>
  `,
  styles: [
    `
      .pager {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        padding: 12px 16px;
        border-top: 1px solid var(--k-outline);
      }
      .count {
        font-size: 13px;
        color: var(--k-text-secondary);
      }
    `,
  ],
})
export class Pagination {
  readonly page = input(0);
  readonly pageSize = input(20);
  readonly total = input(0);
  readonly hasMore = input(false);
  @Output() readonly go = new EventEmitter<number>();

  readonly from = computed(() =>
    this.total() === 0 ? 0 : this.page() * this.pageSize() + 1,
  );
  readonly to = computed(() =>
    Math.min(this.total(), (this.page() + 1) * this.pageSize()),
  );
}

@Component({
  selector: 'k-avatar',
  standalone: true,
  imports: [CommonModule],
  template: `
    <span class="avatar" [style.width.px]="size()" [style.height.px]="size()">
      {{ initials() }}
    </span>
  `,
  styles: [
    `
      .avatar {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border-radius: 50%;
        background: var(--k-primary-container);
        color: var(--k-primary-dark);
        font-size: 12px;
        font-weight: 700;
        flex: none;
      }
    `,
  ],
})
export class UserAvatar {
  readonly name = input('');
  readonly size = input(32);

  readonly initials = computed(() =>
    this.name()
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? '')
      .join(''),
  );
}

@Component({
  selector: 'k-stat',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="stat k-card">
      <p class="label">{{ label() }}</p>
      <p class="value" [class.value--accent]="accent()">{{ value() }}</p>
      @if (hint()) {
        <p class="hint">{{ hint() }}</p>
      }
    </div>
  `,
  styles: [
    `
      .stat {
        padding: 16px 18px;
      }
      .label {
        margin: 0;
        font-size: 12px;
        font-weight: 650;
        text-transform: uppercase;
        letter-spacing: 0.04em;
        color: var(--k-text-tertiary);
      }
      .value {
        margin: 8px 0 0;
        font-size: 22px;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
      }
      .value--accent {
        color: var(--k-primary);
      }
      .hint {
        margin: 4px 0 0;
        font-size: 12.5px;
        color: var(--k-text-secondary);
      }
    `,
  ],
})
export class StatCard {
  readonly label = input.required<string>();
  readonly value = input.required<string>();
  readonly hint = input<string | null>(null);
  readonly accent = input(false);
}

export interface ConfirmRequest {
  title: string;
  message: string;
  confirmLabel?: string;
  danger?: boolean;
  /** Motif obligatoire (forçage de tirage, annulation de paiement…). */
  reasonLabel?: string;
}

@Component({
  selector: 'k-confirm',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    @if (request(); as req) {
      <div class="backdrop" (click)="cancel()">
        <div class="dialog k-card" (click)="$event.stopPropagation()">
          <div class="k-card__header">
            <h3 class="k-card__title">{{ req.title }}</h3>
          </div>
          <div class="k-card__body k-stack">
            <p class="message">{{ req.message }}</p>
            @if (req.reasonLabel) {
              <label class="k-field">
                <span class="k-label">{{ req.reasonLabel }}</span>
                <textarea
                  class="k-textarea"
                  rows="3"
                  [(ngModel)]="reason"
                  placeholder="Motif obligatoire"
                ></textarea>
              </label>
            }
            <div class="k-row" style="justify-content: flex-end">
              <button type="button" class="k-btn k-btn--ghost" (click)="cancel()">
                Annuler
              </button>
              <button
                type="button"
                class="k-btn"
                [class.k-btn--danger]="req.danger"
                [disabled]="!!req.reasonLabel && reason.trim().length < 3"
                (click)="accept()"
              >
                {{ req.confirmLabel ?? 'Confirmer' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    }
  `,
  styles: [
    `
      .backdrop {
        position: fixed;
        inset: 0;
        z-index: 60;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
        background: rgb(13 20 17 / 45%);
      }
      .dialog {
        width: min(460px, 100%);
        box-shadow: var(--k-shadow);
      }
      .message {
        margin: 0;
        color: var(--k-text-secondary);
      }
    `,
  ],
})
export class ConfirmDialog {
  @Input() set open(value: ConfirmRequest | null) {
    this.request.set(value);
    this.reason = '';
  }

  readonly request = signal<ConfirmRequest | null>(null);
  reason = '';

  @Output() readonly confirmed = new EventEmitter<string>();
  @Output() readonly cancelled = new EventEmitter<void>();

  accept(): void {
    this.confirmed.emit(this.reason.trim());
    this.request.set(null);
  }

  cancel(): void {
    this.cancelled.emit();
    this.request.set(null);
  }
}

/** Barres verticales : évolution attendu / collecté, sans librairie externe. */
@Component({
  selector: 'k-bar-chart',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="chart">
      @for (point of points(); track point.label) {
        <div class="col" [title]="point.label">
          <div class="bars">
            <span
              class="bar bar--expected"
              [style.height.%]="height(point.expected)"
            ></span>
            <span
              class="bar bar--collected"
              [style.height.%]="height(point.collected)"
            ></span>
          </div>
          <span class="label">{{ point.label }}</span>
        </div>
      }
    </div>
    <div class="legend">
      <span><i class="dot dot--expected"></i> Attendu</span>
      <span><i class="dot dot--collected"></i> Collecté</span>
    </div>
  `,
  styles: [
    `
      .chart {
        display: flex;
        align-items: flex-end;
        gap: 14px;
        height: 170px;
        padding-top: 8px;
      }
      .col {
        display: flex;
        flex: 1;
        flex-direction: column;
        align-items: center;
        gap: 8px;
        height: 100%;
        min-width: 0;
      }
      .bars {
        display: flex;
        align-items: flex-end;
        gap: 4px;
        width: 100%;
        height: 100%;
        justify-content: center;
      }
      .bar {
        width: 16px;
        min-height: 3px;
        border-radius: 4px 4px 0 0;
      }
      .bar--expected {
        background: var(--k-primary-container);
      }
      .bar--collected {
        background: var(--k-primary);
      }
      .label {
        font-size: 11.5px;
        color: var(--k-text-tertiary);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 100%;
      }
      .legend {
        display: flex;
        gap: 16px;
        margin-top: 12px;
        font-size: 12.5px;
        color: var(--k-text-secondary);
      }
      .dot {
        display: inline-block;
        width: 10px;
        height: 10px;
        border-radius: 3px;
        margin-right: 6px;
      }
      .dot--expected {
        background: var(--k-primary-container);
      }
      .dot--collected {
        background: var(--k-primary);
      }
    `,
  ],
})
export class BarChart {
  readonly points = input.required<{ label: string; expected: number; collected: number }[]>();

  private readonly max = computed(() =>
    Math.max(1, ...this.points().flatMap((p) => [p.expected, p.collected])),
  );

  height(value: number): number {
    return Math.max(2, (value / this.max()) * 100);
  }
}
