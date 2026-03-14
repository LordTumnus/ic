<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution, ChildEntries } from '$lib/types';
  import logger from '$lib/core/logger';

  let {
    items = $bindable([]),
    value = $bindable(''),
    label = $bindable(''),
    variant = $bindable('primary'),
    size = $bindable('md'),
    disabled = $bindable(false),
    labelPosition = $bindable('right'),
    orientation = $bindable('vertical'),
    childEntries = {} as ChildEntries,
    valueChanged,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    items?: string[] | string;
    value?: string;
    label?: string;
    variant?: string;
    size?: string;
    disabled?: boolean;
    labelPosition?: string;
    orientation?: string;
    childEntries?: ChildEntries;
    valueChanged?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  let groupEl: HTMLDivElement;
  let focusedItem = $state('');

  // Normalize MATLAB serialization: scalar string → array
  const itemList = $derived(
    Array.isArray(items) ? items : items ? [items] : []
  );

  onMount(() => {
    focus = (): Resolution => {
      const input = groupEl?.querySelector('input:not(:disabled)') as HTMLInputElement | null;
      input?.focus();
      return { success: true, data: null };
    };
  });

  function hasIcon(item: string): boolean {
    return (childEntries[item]?.length ?? 0) > 0;
  }

  function handleSelect(item: string) {
    if (disabled) return;
    value = item;
    valueChanged?.({ value });
    logger.debug('RadioButton', `selected '${item}'`);
  }
</script>

<div
  bind:this={groupEl}
  class="ic-radio"
  class:ic-radio--sm={size === 'sm'}
  class:ic-radio--md={size === 'md'}
  class:ic-radio--lg={size === 'lg'}
  class:ic-radio--disabled={disabled}
  class:ic-radio--horizontal={orientation === 'horizontal'}
  role="radiogroup"
  aria-label={label || undefined}
>
  {#if label}
    <span class="ic-radio__group-label">{label}</span>
  {/if}

  {#each itemList as item (item)}
    {@const isSelected = value === item}
    {@const isFocused = focusedItem === item}
    <label
      class="ic-radio__item"
      class:ic-radio__item--label-left={labelPosition === 'left'}
    >
      {#if labelPosition === 'left'}
        <span class="ic-radio__item-content">
          {#if hasIcon(item)}
            <span class="ic-radio__icon">
              {#each childEntries[item] ?? [] as iconSnippet (iconSnippet)}
                {@render iconSnippet.snippet()}
              {/each}
            </span>
          {/if}
          <span class="ic-radio__label">{item}</span>
        </span>
      {/if}

      <span
        class="ic-radio__circle"
        class:ic-radio__circle--selected={isSelected}
        class:ic-radio__circle--focused={isFocused}
        class:ic-radio__circle--primary={variant === 'primary'}
        class:ic-radio__circle--secondary={variant === 'secondary'}
        class:ic-radio__circle--destructive={variant === 'destructive'}
      >
        <input
          type="radio"
          class="ic-radio__input"
          name="ic-radio-group"
          checked={isSelected}
          {disabled}
          onchange={() => handleSelect(item)}
          onfocus={() => focusedItem = item}
          onblur={() => focusedItem = ''}
        />
        {#if isSelected}
          <span class="ic-radio__dot"></span>
        {/if}
      </span>

      {#if labelPosition === 'right'}
        <span class="ic-radio__item-content">
          {#if hasIcon(item)}
            <span class="ic-radio__icon">
              {#each childEntries[item] ?? [] as iconSnippet (iconSnippet)}
                {@render iconSnippet.snippet()}
              {/each}
            </span>
          {/if}
          <span class="ic-radio__label">{item}</span>
        </span>
      {/if}
    </label>
  {/each}
</div>

<style>
  /* ===== GROUP CONTAINER ===== */
  .ic-radio {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }

  .ic-radio--horizontal {
    flex-direction: row;
    flex-wrap: wrap;
    gap: 0.75rem;
  }

  .ic-radio--disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ===== GROUP LABEL ===== */
  .ic-radio__group-label {
    font-family: inherit;
    font-weight: 500;
    color: var(--ic-foreground);
    margin-bottom: 0.125rem;
  }

  .ic-radio--sm .ic-radio__group-label { font-size: 0.75rem; }
  .ic-radio--md .ic-radio__group-label { font-size: 0.8125rem; }
  .ic-radio--lg .ic-radio__group-label { font-size: 0.875rem; }

  /* ===== ITEM (label wrapper) ===== */
  .ic-radio__item {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    cursor: pointer;
    user-select: none;
  }

  .ic-radio--disabled .ic-radio__item {
    cursor: not-allowed;
  }

  /* ===== ITEM CONTENT (icon + label) ===== */
  .ic-radio__item-content {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
  }

  /* ===== ITEM LABEL ===== */
  .ic-radio__label {
    font-family: inherit;
    color: var(--ic-foreground);
    white-space: nowrap;
  }

  .ic-radio--sm .ic-radio__label { font-size: 0.75rem; }
  .ic-radio--md .ic-radio__label { font-size: 0.8125rem; }
  .ic-radio--lg .ic-radio__label { font-size: 0.875rem; }

  /* ===== ICON ===== */
  .ic-radio__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
  }

  /* ===== CIRCLE (the radio indicator) ===== */
  .ic-radio__circle {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    border-radius: 50%;
    border: 1px solid transparent;
    background-color: var(--ic-secondary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.18);
    transition: background-color 0.1s ease, box-shadow 0.1s ease, border-color 0.15s ease;
  }

  .ic-radio--sm .ic-radio__circle { width: 12px; height: 12px; }
  .ic-radio--md .ic-radio__circle { width: 14px; height: 14px; }
  .ic-radio--lg .ic-radio__circle { width: 18px; height: 18px; }

  /* ===== HIDDEN INPUT ===== */
  .ic-radio__input {
    position: absolute;
    inset: 0;
    opacity: 0;
    cursor: pointer;
    margin: 0;
    width: 100%;
    height: 100%;
  }

  .ic-radio--disabled .ic-radio__input {
    cursor: not-allowed;
  }

  /* ===== DOT (selected indicator) ===== */
  .ic-radio__dot {
    width: 34%;
    height: 34%;
    border-radius: 50%;
    background-color: currentColor;
    opacity: 0.85;
    pointer-events: none;
  }

  /* ===== SELECTED STATES ===== */
  .ic-radio__circle--primary.ic-radio__circle--selected {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.25);
  }

  .ic-radio__circle--secondary.ic-radio__circle--selected {
    background-color: var(--ic-muted-foreground);
    color: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.2);
  }

  .ic-radio__circle--destructive.ic-radio__circle--selected {
    background-color: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.25);
  }

  /* ===== HOVER ===== */
  .ic-radio__item:hover:not(.ic-radio--disabled *) .ic-radio__circle {
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.25);
  }
  .ic-radio__item:hover:not(.ic-radio--disabled *) .ic-radio__circle--selected {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.3);
  }

  /* ===== FOCUS (border-color approach, matches Checkbox/InputText) ===== */
  .ic-radio__circle--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }
  .ic-radio__circle--focused.ic-radio__circle--selected {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.3);
  }
</style>
