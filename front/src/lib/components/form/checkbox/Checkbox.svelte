<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution, ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    value = $bindable('off'),
    label = $bindable(''),
    variant = $bindable('primary'),
    size = $bindable('md'),
    disabled = $bindable(false),
    indeterminate = $bindable(false),
    labelPosition = $bindable('right'),
    childEntries = [] as ChildEntries,
    valueChanged,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    value?: string;
    label?: string;
    variant?: string;
    size?: string;
    disabled?: boolean;
    indeterminate?: boolean;
    labelPosition?: string;
    childEntries?: ChildEntries;
    valueChanged?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  let inputEl: HTMLInputElement;
  let focused = $state(false);

  const isOn = $derived(value === 'on');
  const iconEntries = $derived(childEntries.filter(c => c.type === 'ic.Icon' || c.type === 'ic.Image'));
  const hasIcon = $derived(iconEntries.length > 0);

  onMount(() => {
    focus = (): Resolution => {
      inputEl?.focus();
      return { success: true, data: null };
    };
  });

  $effect(() => {
    if (inputEl) {
      inputEl.indeterminate = indeterminate;
    }
  });

  function handleChange() {
    if (disabled) return;
    indeterminate = false;
    value = isOn ? 'off' : 'on';
    valueChanged?.({ value });
  }
</script>

<label {id}
  class="ic-checkbox"
  class:ic-checkbox--sm={size === 'sm'}
  class:ic-checkbox--md={size === 'md'}
  class:ic-checkbox--lg={size === 'lg'}
  class:ic-checkbox--disabled={disabled}
>
  {#if label && labelPosition === 'left'}
    <span class="ic-checkbox__label">{label}</span>
  {/if}

  <span
    class="ic-checkbox__box"
    class:ic-checkbox__box--checked={isOn}
    class:ic-checkbox__box--indeterminate={indeterminate}
    class:ic-checkbox__box--focused={focused}
    class:ic-checkbox__box--primary={variant === 'primary'}
    class:ic-checkbox__box--secondary={variant === 'secondary'}
    class:ic-checkbox__box--destructive={variant === 'destructive'}
  >
    <input
      bind:this={inputEl}
      type="checkbox"
      class="ic-checkbox__input"
      checked={isOn}
      {disabled}
      onchange={handleChange}
      onfocus={() => focused = true}
      onblur={() => focused = false}
    />

    {#if indeterminate}
      <svg class="ic-checkbox__indicator" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round">
        <line x1="6" y1="12" x2="18" y2="12" />
      </svg>
    {:else if isOn}
      {#if hasIcon}
        <span class="ic-checkbox__icon">
          {#each iconEntries as iconSnippet (iconSnippet.id)}
            <DynamicChild entry={iconSnippet} />
          {/each}
        </span>
      {:else}
        <svg class="ic-checkbox__indicator" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="4 12 10 18 20 6" />
        </svg>
      {/if}
    {/if}
  </span>

  {#if label && labelPosition === 'right'}
    <span class="ic-checkbox__label">{label}</span>
  {/if}
</label>

<style>
  .ic-checkbox {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    cursor: pointer;
    user-select: none;
  }

  .ic-checkbox--disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ===== LABEL ===== */
  .ic-checkbox__label {
    font-family: inherit;
    color: var(--ic-foreground);
    white-space: nowrap;
  }

  .ic-checkbox--sm .ic-checkbox__label { font-size: 0.75rem; }
  .ic-checkbox--md .ic-checkbox__label { font-size: 0.8125rem; }
  .ic-checkbox--lg .ic-checkbox__label { font-size: 0.9375rem; }

  /* ===== BOX ===== */
  .ic-checkbox__box {
    position: relative;
    display: inline-block;
    flex-shrink: 0;
    border-radius: 2px;
    border: 1px solid transparent;
    background-color: var(--ic-secondary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.18);
    transition: background-color 0.1s ease, box-shadow 0.1s ease, border-color 0.15s ease;
  }

  .ic-checkbox--sm .ic-checkbox__box { width: 12px; height: 12px; }
  .ic-checkbox--md .ic-checkbox__box { width: 14px; height: 14px; }
  .ic-checkbox--lg .ic-checkbox__box { width: 18px; height: 18px; }

  /* ===== HIDDEN INPUT ===== */
  .ic-checkbox__input {
    position: absolute;
    inset: 0;
    opacity: 0;
    cursor: pointer;
    margin: 0;
    width: 100%;
    height: 100%;
  }

  .ic-checkbox--disabled .ic-checkbox__input {
    cursor: not-allowed;
  }

  /* ===== CHECKED STATES ===== */
  .ic-checkbox__box--primary.ic-checkbox__box--checked,
  .ic-checkbox__box--primary.ic-checkbox__box--indeterminate {
    background-color: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.25);
  }
  .ic-checkbox__box--primary.ic-checkbox__box--checked .ic-checkbox__indicator,
  .ic-checkbox__box--primary.ic-checkbox__box--checked .ic-checkbox__icon,
  .ic-checkbox__box--primary.ic-checkbox__box--indeterminate .ic-checkbox__indicator {
    color: var(--ic-primary-foreground);
  }

  .ic-checkbox__box--secondary.ic-checkbox__box--checked,
  .ic-checkbox__box--secondary.ic-checkbox__box--indeterminate {
    background-color: var(--ic-muted-foreground);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.2);
  }
  .ic-checkbox__box--secondary.ic-checkbox__box--checked .ic-checkbox__indicator,
  .ic-checkbox__box--secondary.ic-checkbox__box--checked .ic-checkbox__icon,
  .ic-checkbox__box--secondary.ic-checkbox__box--indeterminate .ic-checkbox__indicator {
    color: var(--ic-secondary);
  }

  .ic-checkbox__box--destructive.ic-checkbox__box--checked,
  .ic-checkbox__box--destructive.ic-checkbox__box--indeterminate {
    background-color: var(--ic-destructive);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.25);
  }
  .ic-checkbox__box--destructive.ic-checkbox__box--checked .ic-checkbox__indicator,
  .ic-checkbox__box--destructive.ic-checkbox__box--checked .ic-checkbox__icon,
  .ic-checkbox__box--destructive.ic-checkbox__box--indeterminate .ic-checkbox__indicator {
    color: var(--ic-destructive-foreground);
  }

  /* ===== INDICATOR (absolutely positioned — no layout shift) ===== */
  .ic-checkbox__indicator {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    padding: 10%;
    pointer-events: none;
  }

  /* ===== CUSTOM ICON (replaces checkmark inside the box) ===== */
  .ic-checkbox__icon {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: none;
    color: inherit;
  }

  /* ===== HOVER ===== */
  .ic-checkbox:hover:not(.ic-checkbox--disabled) .ic-checkbox__box {
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.25);
  }
  .ic-checkbox:hover:not(.ic-checkbox--disabled) .ic-checkbox__box--checked,
  .ic-checkbox:hover:not(.ic-checkbox--disabled) .ic-checkbox__box--indeterminate {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.3);
  }

  /* ===== FOCUS (matches InputText: border-color + deeper inset) ===== */
  .ic-checkbox__box--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }
  .ic-checkbox__box--focused.ic-checkbox__box--checked,
  .ic-checkbox__box--focused.ic-checkbox__box--indeterminate {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.3);
  }
</style>
