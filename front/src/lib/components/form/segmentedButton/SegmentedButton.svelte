<script lang="ts">
  import type { Resolution, Snippets } from '$lib/types';
  import logger from '$lib/core/logger';

  let {
    items = $bindable([]),
    value = $bindable([]),
    multiselect = $bindable(false),
    showLabels = $bindable(true),
    variant = $bindable('primary'),
    size = $bindable('md'),
    disabled = $bindable(false),
    iconPosition = $bindable('left'),
    snippets = { default: [] } as Snippets,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    items?: string[] | string;
    value?: string[] | string;
    multiselect?: boolean;
    showLabels?: boolean;
    variant?: string;
    size?: string;
    disabled?: boolean;
    iconPosition?: string;
    snippets?: Snippets;
    focus?: () => Resolution;
  } = $props();

  let containerEl: HTMLDivElement;

  // Normalize MATLAB serialization: scalar string → array
  const itemList = $derived(
    Array.isArray(items) ? items : items ? [items] : []
  );

  const selected = $derived(
    new Set(Array.isArray(value) ? value : value ? [value] : [])
  );

  $effect(() => {
    focus = (): Resolution => {
      const btn = containerEl?.querySelector('button:not(:disabled)') as HTMLButtonElement | null;
      btn?.focus();
      return { success: true, data: null };
    };
  });

  function hasIcon(item: string): boolean {
    return (snippets[item]?.length ?? 0) > 0;
  }

  function handleClick(item: string) {
    if (disabled) return;

    if (multiselect) {
      const current = Array.isArray(value) ? [...value] : value ? [value] : [];
      const idx = current.indexOf(item);
      if (idx >= 0) {
        current.splice(idx, 1);
      } else {
        current.push(item);
      }
      value = current;
    } else {
      // Single select: scalar value
      value = item;
    }

    logger.debug('SegmentedButton', `toggled '${item}'`);
  }
</script>

<div
  bind:this={containerEl}
  class="ic-seg-btn"
  class:ic-seg-btn--sm={size === 'sm'}
  class:ic-seg-btn--md={size === 'md'}
  class:ic-seg-btn--lg={size === 'lg'}
  class:ic-seg-btn--disabled={disabled}
  role="group"
>
  {#each itemList as item, i (item)}
    <button
      class="ic-seg-btn__item"
      class:ic-seg-btn__item--selected={selected.has(item)}
      class:ic-seg-btn__item--primary={variant === 'primary'}
      class:ic-seg-btn__item--secondary={variant === 'secondary'}
      class:ic-seg-btn__item--destructive={variant === 'destructive'}
      class:ic-seg-btn__item--first={i === 0}
      class:ic-seg-btn__item--last={i === itemList.length - 1}
      class:ic-seg-btn__item--icon-only={hasIcon(item) && !showLabels}
      aria-pressed={selected.has(item)}
      aria-label={!showLabels ? item : undefined}
      {disabled}
      onclick={() => handleClick(item)}
    >
      {#if hasIcon(item)}
        <span class="ic-seg-btn__icon" class:ic-seg-btn__icon--right={iconPosition === 'right'}>
          {#each snippets[item] ?? [] as iconSnippet (iconSnippet)}
            {@render iconSnippet()}
          {/each}
        </span>
      {/if}

      {#if showLabels}
        <span class="ic-seg-btn__label">{item}</span>
      {/if}
    </button>
  {/each}
</div>

<style>
  /* ===== CONTAINER (recessed housing) ===== */
  .ic-seg-btn {
    display: inline-flex;
    border-radius: 2px;
    background-color: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    padding: 2px;
  }

  .ic-seg-btn--disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ===== SEGMENT ITEMS ===== */
  .ic-seg-btn__item {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.35rem;
    border: 1.5px solid transparent;
    border-radius: 1px;
    background-color: transparent;
    color: var(--ic-muted-foreground);
    font-family: inherit;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
    outline: none;
    white-space: nowrap;
    flex: 1;
  }

  /* ===== DIVIDERS ===== */
  .ic-seg-btn__item:not(:first-child)::before {
    content: '';
    position: absolute;
    left: 0;
    top: 20%;
    height: 60%;
    width: 1px;
    background-color: var(--ic-border);
    transition: opacity 0.15s ease;
  }

  /* Hide divider when this item or the previous item is selected */
  .ic-seg-btn__item--selected::before,
  .ic-seg-btn__item--selected + .ic-seg-btn__item::before {
    opacity: 0;
  }

  .ic-seg-btn__item:disabled {
    cursor: not-allowed;
  }

  /* ===== SIZES ===== */
  .ic-seg-btn--sm .ic-seg-btn__item {
    padding: 0.25rem 0.5rem;
    font-size: 0.75rem;
  }

  .ic-seg-btn--md .ic-seg-btn__item {
    padding: 0.375rem 0.75rem;
    font-size: 0.8125rem;
  }

  .ic-seg-btn--lg .ic-seg-btn__item {
    padding: 0.5rem 1rem;
    font-size: 0.875rem;
  }

  /* Icon-only: square padding */
  .ic-seg-btn--sm .ic-seg-btn__item--icon-only { padding: 0.375rem; }
  .ic-seg-btn--md .ic-seg-btn__item--icon-only { padding: 0.5rem; }
  .ic-seg-btn--lg .ic-seg-btn__item--icon-only { padding: 0.625rem; }

  /* ===== HOVER (unselected) ===== */
  .ic-seg-btn__item:hover:not(:disabled):not(.ic-seg-btn__item--selected) {
    color: var(--ic-foreground);
    background-color: rgba(0, 0, 0, 0.04);
  }

  /* ===== SELECTED STATE ===== */
  .ic-seg-btn__item--selected {
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* Primary selected */
  .ic-seg-btn__item--primary.ic-seg-btn__item--selected {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
  }

  .ic-seg-btn__item--primary.ic-seg-btn__item--selected:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  /* Secondary selected */
  .ic-seg-btn__item--secondary.ic-seg-btn__item--selected {
    background-color: var(--ic-background);
    color: var(--ic-foreground);
  }

  .ic-seg-btn__item--secondary.ic-seg-btn__item--selected:hover:not(:disabled) {
    filter: brightness(0.97);
  }

  /* Destructive selected */
  .ic-seg-btn__item--destructive.ic-seg-btn__item--selected {
    background-color: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
  }

  .ic-seg-btn__item--destructive.ic-seg-btn__item--selected:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  /* ===== FOCUS ===== */
  .ic-seg-btn__item:focus-visible {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.3),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
    z-index: 1;
  }

  /* ===== CHILDREN ===== */
  .ic-seg-btn__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
  }

  .ic-seg-btn__icon--right {
    order: 1;
  }

  .ic-seg-btn__label {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
