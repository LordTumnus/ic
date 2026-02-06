<script lang="ts">
  import type { Resolution, Snippets } from '$lib/types';

  let {
    label = $bindable(''),
    variant = $bindable('primary'),
    fill = $bindable('solid'),
    shape = $bindable('default'),
    size = $bindable('md'),
    disabled = $bindable(false),
    iconPosition = $bindable('left'),
    snippets = { default: [], icon: [] } as Snippets,
    clicked,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    label?: string;
    variant?: string;
    fill?: string;
    shape?: string;
    size?: string;
    disabled?: boolean;
    iconPosition?: string;
    snippets?: Snippets;
    clicked?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  let buttonEl: HTMLButtonElement;

  const hasIcon = $derived((snippets.icon?.length ?? 0) > 0);
  const iconOnly = $derived(hasIcon && !label);

  $effect(() => {
    focus = (): Resolution => {
      buttonEl?.focus();
      return { success: true, data: null };
    };
  });

  function handleClick() {
    if (!disabled) {
      clicked?.({ timestamp: Date.now() });
    }
  }
</script>

<button
  bind:this={buttonEl}
  class="ic-btn"
  class:ic-btn--primary={variant === 'primary'}
  class:ic-btn--secondary={variant === 'secondary'}
  class:ic-btn--destructive={variant === 'destructive'}
  class:ic-btn--solid={fill === 'solid'}
  class:ic-btn--outline={fill === 'outline'}
  class:ic-btn--ghost={fill === 'ghost'}
  class:ic-btn--default={shape === 'default'}
  class:ic-btn--pill={shape === 'pill'}
  class:ic-btn--square={shape === 'square'}
  class:ic-btn--sm={size === 'sm'}
  class:ic-btn--md={size === 'md'}
  class:ic-btn--lg={size === 'lg'}
  class:ic-btn--icon-only={iconOnly}
  class:ic-btn--disabled={disabled}
  {disabled}
  onclick={handleClick}
>
  {#if hasIcon && iconPosition === 'left'}
    <span class="ic-btn__icon">
      {#each snippets.icon ?? [] as iconSnippet}
        {@render iconSnippet()}
      {/each}
    </span>
  {/if}

  {#if label}
    <span class="ic-btn__label">{label}</span>
  {/if}

  {#if hasIcon && iconPosition === 'right'}
    <span class="ic-btn__icon">
      {#each snippets.icon ?? [] as iconSnippet}
        {@render iconSnippet()}
      {/each}
    </span>
  {/if}
</button>

<style>
  .ic-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    border: 1.5px solid transparent;
    font-family: inherit;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
    outline: none;
    min-width: 0;
  }

  /* ===== SIZE ===== */
  .ic-btn--sm {
    padding: 0.25rem 0.5rem;
  }

  .ic-btn--md {
    padding: 0.375rem 0.75rem;
  }

  .ic-btn--lg {
    padding: 0.5rem 1rem;
  }

  .ic-btn--icon-only.ic-btn--sm {
    padding: 0.375rem;
  }
  .ic-btn--icon-only.ic-btn--md {
    padding: 0.5rem;
  }
  .ic-btn--icon-only.ic-btn--lg {
    padding: 0.625rem;
  }

  /* ===== SHAPE ===== */
  .ic-btn--default {
    border-radius: 2px;
  }

  .ic-btn--pill {
    border-radius: 3px;
  }

  .ic-btn--square {
    border-radius: 0;
  }

  /* ===== PRIMARY ===== */
  .ic-btn--primary.ic-btn--solid {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
    border-color: transparent;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }
  .ic-btn--primary.ic-btn--solid:hover:not(:disabled) {
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-btn--primary.ic-btn--outline {
    background-color: transparent;
    color: var(--ic-primary);
    border-color: var(--ic-primary);
  }
  .ic-btn--primary.ic-btn--outline:hover:not(:disabled) {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-btn--primary.ic-btn--ghost {
    background-color: transparent;
    color: var(--ic-primary);
    border-color: transparent;
  }
  .ic-btn--primary.ic-btn--ghost:hover:not(:disabled) {
    background-color: var(--ic-muted);
  }

  /* ===== SECONDARY ===== */
  .ic-btn--secondary.ic-btn--solid {
    background-color: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    border-color: transparent;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.15),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
  }
  .ic-btn--secondary.ic-btn--solid:hover:not(:disabled) {
    background-color: var(--ic-muted);
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
  }

  .ic-btn--secondary.ic-btn--outline {
    background-color: transparent;
    color: var(--ic-secondary-foreground);
    border-color: var(--ic-border);
  }
  .ic-btn--secondary.ic-btn--outline:hover:not(:disabled) {
    background-color: var(--ic-secondary);
    border-color: var(--ic-muted-foreground);
  }

  .ic-btn--secondary.ic-btn--ghost {
    background-color: transparent;
    color: var(--ic-secondary-foreground);
    border-color: transparent;
  }
  .ic-btn--secondary.ic-btn--ghost:hover:not(:disabled) {
    background-color: var(--ic-secondary);
  }

  /* ===== DESTRUCTIVE ===== */
  .ic-btn--destructive.ic-btn--solid {
    background-color: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
    border-color: transparent;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }
  .ic-btn--destructive.ic-btn--solid:hover:not(:disabled) {
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-btn--destructive.ic-btn--outline {
    background-color: transparent;
    color: var(--ic-destructive);
    border-color: var(--ic-destructive);
  }
  .ic-btn--destructive.ic-btn--outline:hover:not(:disabled) {
    background-color: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-btn--destructive.ic-btn--ghost {
    background-color: transparent;
    color: var(--ic-destructive);
    border-color: transparent;
  }
  .ic-btn--destructive.ic-btn--ghost:hover:not(:disabled) {
    background-color: var(--ic-muted);
  }

  /* ===== FOCUS ===== */
  .ic-btn:focus-visible {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.3),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* ===== DISABLED ===== */
  .ic-btn--disabled,
  .ic-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ===== CHILDREN ===== */
  .ic-btn__icon {
    display: inline-flex;
    flex-shrink: 0;
  }

  .ic-btn__label {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
