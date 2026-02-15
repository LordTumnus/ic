<script lang="ts">
  let {
    value,
    config = {},
    disabled = false,
    onclick,
  }: {
    value?: unknown;
    config?: Record<string, unknown>;
    disabled?: boolean;
    onclick?: () => void;
  } = $props();

  const label = $derived((config.label as string) ?? String(value ?? 'Action'));
  const variant = $derived((config.variant as string) ?? 'primary');
  const fill = $derived((config.fill as string) ?? 'outline');
</script>

<button
  class="ic-tbl-cell-btn"
  class:ic-tbl-cell-btn--primary={variant === 'primary'}
  class:ic-tbl-cell-btn--secondary={variant === 'secondary'}
  class:ic-tbl-cell-btn--destructive={variant === 'destructive'}
  class:ic-tbl-cell-btn--solid={fill === 'solid'}
  class:ic-tbl-cell-btn--outline={fill === 'outline'}
  class:ic-tbl-cell-btn--ghost={fill === 'ghost'}
  class:ic-tbl-cell-btn--disabled={disabled}
  {disabled}
  onclick={(e: MouseEvent) => { e.stopPropagation(); onclick?.(); }}
>
  {label}
</button>

<style>
  .ic-tbl-cell-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 2px 8px;
    border-radius: 2px;
    font-size: 0.75em;
    font-weight: 500;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.15s ease;
    line-height: 1.4;
    border: 1.5px solid transparent;
    background: transparent;
    color: var(--ic-foreground);
  }

  /* Solid */
  .ic-tbl-cell-btn--solid.ic-tbl-cell-btn--primary {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }
  .ic-tbl-cell-btn--solid.ic-tbl-cell-btn--destructive {
    background: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }
  .ic-tbl-cell-btn--solid.ic-tbl-cell-btn--secondary {
    background: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1), inset 0 1px 0 rgba(255, 255, 255, 0.08);
  }

  /* Outline */
  .ic-tbl-cell-btn--outline.ic-tbl-cell-btn--primary {
    border-color: var(--ic-primary);
    color: var(--ic-primary);
  }
  .ic-tbl-cell-btn--outline.ic-tbl-cell-btn--destructive {
    border-color: var(--ic-destructive);
    color: var(--ic-destructive);
  }
  .ic-tbl-cell-btn--outline.ic-tbl-cell-btn--secondary {
    border-color: var(--ic-border);
    color: var(--ic-foreground);
  }

  /* Ghost */
  .ic-tbl-cell-btn--ghost {
    border-color: transparent;
  }
  .ic-tbl-cell-btn--ghost.ic-tbl-cell-btn--primary { color: var(--ic-primary); }
  .ic-tbl-cell-btn--ghost.ic-tbl-cell-btn--destructive { color: var(--ic-destructive); }

  .ic-tbl-cell-btn:hover:not(.ic-tbl-cell-btn--disabled) {
    filter: brightness(0.92);
  }
  .ic-tbl-cell-btn--disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
