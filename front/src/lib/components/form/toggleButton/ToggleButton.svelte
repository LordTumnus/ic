<script lang="ts">
  import type { Resolution } from '$lib/types';
  import logger from '$lib/core/logger';

  let {
    label = $bindable(''),
    value = $bindable(false),
    variant = $bindable('primary'),
    size = $bindable('md'),
    disabled = $bindable(false),
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    label?: string;
    value?: boolean;
    variant?: string;
    size?: string;
    disabled?: boolean;
    focus?: () => Resolution;
  } = $props();

  let buttonEl: HTMLButtonElement;

  $effect(() => {
    focus = (): Resolution => {
      buttonEl?.focus();
      return { success: true, data: null };
    };
  });

  function handleClick() {
    if (!disabled) {
      value = !value;
      logger.debug('ToggleButton', 'toggled', { value });
    }
  }
</script>

<button
  bind:this={buttonEl}
  class="ic-toggle-btn"
  class:ic-toggle-btn--on={value}
  class:ic-toggle-btn--primary={variant === 'primary'}
  class:ic-toggle-btn--secondary={variant === 'secondary'}
  class:ic-toggle-btn--destructive={variant === 'destructive'}
  class:ic-toggle-btn--sm={size === 'sm'}
  class:ic-toggle-btn--md={size === 'md'}
  class:ic-toggle-btn--lg={size === 'lg'}
  class:ic-toggle-btn--disabled={disabled}
  aria-pressed={value}
  {disabled}
  onclick={handleClick}
>
  {#if label}
    <span class="ic-toggle-btn__label">{label}</span>
  {/if}

  <span class="ic-toggle-btn__indicator"></span>
</button>

<style>
  .ic-toggle-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    border: 1.5px solid var(--ic-border);
    border-radius: 2px;
    font-family: inherit;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
    outline: none;
    background-color: var(--ic-background);
    color: var(--ic-foreground);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.15),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
  }

  /* ===== SIZE ===== */
  .ic-toggle-btn--sm { padding: 0.25rem 0.5rem; font-size: 0.75rem; }
  .ic-toggle-btn--md { padding: 0.375rem 0.75rem; font-size: 0.8125rem; }
  .ic-toggle-btn--lg { padding: 0.5rem 1rem; font-size: 0.875rem; }

  /* ===== INDICATOR (lit dot) ===== */
  .ic-toggle-btn__indicator {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background-color: var(--ic-muted-foreground);
    opacity: 0.35;
    transition: all 0.15s ease;
    flex-shrink: 0;
  }

  /* ===== HOVER (released) ===== */
  .ic-toggle-btn:hover:not(:disabled) {
    background-color: var(--ic-muted);
  }

  /* ===== PRESSED STATE ===== */
  .ic-toggle-btn--on {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.2);
    border-color: transparent;
  }

  /* ===== PRIMARY PRESSED ===== */
  .ic-toggle-btn--primary.ic-toggle-btn--on {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
  }

  .ic-toggle-btn--primary.ic-toggle-btn--on .ic-toggle-btn__indicator {
    background-color: var(--ic-primary-foreground);
    opacity: 1;
    box-shadow: 0 0 4px rgba(255, 255, 255, 0.5);
  }

  .ic-toggle-btn--primary.ic-toggle-btn--on:hover:not(:disabled) {
    background-color: var(--ic-primary);
    filter: brightness(1.1);
  }

  /* ===== SECONDARY PRESSED ===== */
  .ic-toggle-btn--secondary.ic-toggle-btn--on {
    background-color: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    border-color: var(--ic-muted-foreground);
  }

  .ic-toggle-btn--secondary.ic-toggle-btn--on .ic-toggle-btn__indicator {
    background-color: var(--ic-secondary-foreground);
    opacity: 0.9;
  }

  .ic-toggle-btn--secondary.ic-toggle-btn--on:hover:not(:disabled) {
    background-color: var(--ic-secondary);
    filter: brightness(0.95);
  }

  /* ===== DESTRUCTIVE PRESSED ===== */
  .ic-toggle-btn--destructive.ic-toggle-btn--on {
    background-color: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
  }

  .ic-toggle-btn--destructive.ic-toggle-btn--on .ic-toggle-btn__indicator {
    background-color: var(--ic-destructive-foreground);
    opacity: 1;
    box-shadow: 0 0 4px rgba(255, 255, 255, 0.5);
  }

  .ic-toggle-btn--destructive.ic-toggle-btn--on:hover:not(:disabled) {
    background-color: var(--ic-destructive);
    filter: brightness(1.1);
  }

  /* ===== FOCUS ===== */
  .ic-toggle-btn:focus-visible {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.3),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-toggle-btn--on:focus-visible {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.3);
  }

  /* ===== DISABLED ===== */
  .ic-toggle-btn--disabled,
  .ic-toggle-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ===== CHILDREN ===== */
  .ic-toggle-btn__label {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
