<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution } from '$lib/types';
  import logger from '$lib/core/logger';

  let {
    id = '',
    value = $bindable(''),
    placeholder = $bindable(''),
    variant = $bindable('primary'),
    size = $bindable('md'),
    disabled = $bindable(false),
    readonly = $bindable(false),
    invalid = $bindable(false),
    errorMessage = $bindable(''),
    helperText = $bindable(''),
    prefix = $bindable(''),
    suffix = $bindable(''),
    clearable = $bindable(false),
    maxLength = $bindable(0),
    showCounter = $bindable(false),
    // Events
    valueChanged,
    submitted,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    blur = $bindable((): Resolution => ({ success: true, data: null })),
    selectAll = $bindable((): Resolution => ({ success: true, data: null })),
    clear = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    value?: string;
    placeholder?: string;
    variant?: string;
    size?: string;
    disabled?: boolean;
    readonly?: boolean;
    invalid?: boolean;
    errorMessage?: string;
    helperText?: string;
    prefix?: string;
    suffix?: string;
    clearable?: boolean;
    maxLength?: number;
    showCounter?: boolean;
    valueChanged?: (data?: unknown) => void;
    submitted?: (data?: unknown) => void;
    focus?: () => Resolution;
    blur?: () => Resolution;
    selectAll?: () => Resolution;
    clear?: () => Resolution;
  } = $props();

  let inputEl: HTMLInputElement;

  // Derived
  const hasPrefix = $derived(prefix.length > 0);
  const hasSuffix = $derived(suffix.length > 0);
  const showClear = $derived(clearable && value.length > 0 && !disabled && !readonly);
  const charCount = $derived(value.length);
  const showCharCounter = $derived(showCounter && maxLength > 0);
  const isNearLimit = $derived(maxLength > 0 && charCount >= maxLength * 0.9);

  // Methods
  onMount(() => {
    focus = (): Resolution => {
      inputEl?.focus();
      return { success: true, data: null };
    };

    blur = (): Resolution => {
      inputEl?.blur();
      return { success: true, data: null };
    };

    selectAll = (): Resolution => {
      inputEl?.focus();
      inputEl?.select();
      return { success: true, data: null };
    };

    clear = (): Resolution => {
      value = '';
      valueChanged?.({ value: '' });
      logger.debug('InputText', 'cleared');
      return { success: true, data: null };
    };
  });

  function handleInput(e: Event) {
    const target = e.currentTarget as HTMLInputElement;
    value = target.value;
    valueChanged?.({ value: target.value });
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      submitted?.({ value });
    }
  }

  function handleClear() {
    value = '';
    valueChanged?.({ value: '' });
    inputEl?.focus();
    logger.debug('InputText', 'cleared via button');
  }
</script>

<div {id}
  class="ic-input-text"
  class:ic-input-text--sm={size === 'sm'}
  class:ic-input-text--md={size === 'md'}
  class:ic-input-text--lg={size === 'lg'}
  class:ic-input-text--disabled={disabled}
  class:ic-input-text--invalid={invalid}
  class:ic-input-text--readonly={readonly}
>
  <div
    class="ic-input-text__field"
    class:ic-input-text__field--primary={variant === 'primary'}
    class:ic-input-text__field--secondary={variant === 'secondary'}
    class:ic-input-text__field--focused={false}
  >
    {#if hasPrefix}
      <span class="ic-input-text__affix ic-input-text__prefix">{prefix}</span>
    {/if}

    <input
      bind:this={inputEl}
      class="ic-input-text__input"
      type="text"
      value={value}
      {placeholder}
      {disabled}
      readonly={readonly}
      maxlength={maxLength > 0 ? maxLength : undefined}
      aria-invalid={invalid || undefined}
      oninput={handleInput}
      onkeydown={handleKeydown}
      onfocus={() => {
        const field = inputEl?.parentElement;
        if (field) field.classList.add('ic-input-text__field--focused');
      }}
      onblur={() => {
        const field = inputEl?.parentElement;
        if (field) field.classList.remove('ic-input-text__field--focused');
      }}
    />

    {#if showClear}
      <button
        class="ic-input-text__clear"
        tabindex="-1"
        aria-label="Clear input"
        onclick={handleClear}
      >
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M10.5 3.5L3.5 10.5M3.5 3.5L10.5 10.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
    {/if}

    {#if hasSuffix}
      <span class="ic-input-text__affix ic-input-text__suffix">{suffix}</span>
    {/if}
  </div>

  {#if invalid && errorMessage}
    <span class="ic-input-text__error">{errorMessage}</span>
  {:else if helperText}
    <span class="ic-input-text__helper">{helperText}</span>
  {/if}

  {#if showCharCounter}
    <span class="ic-input-text__counter" class:ic-input-text__counter--warn={isNearLimit}>
      {charCount}/{maxLength}
    </span>
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-input-text {
    display: inline-flex;
    flex-direction: column;
    gap: 0.25rem;
    font-family: inherit;
    width: 100%;
  }

  /* ===== FIELD WRAPPER (the recessed channel) ===== */
  .ic-input-text__field {
    display: flex;
    align-items: center;
    border-radius: 3px;
    border: 1px solid var(--ic-border);
    background-color: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
    overflow: hidden;
  }

  /* Primary variant */
  .ic-input-text__field--primary {
    border-color: var(--ic-border);
  }

  /* Secondary variant - more recessed */
  .ic-input-text__field--secondary {
    background-color: var(--ic-secondary);
    border-color: transparent;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  /* Focus state */
  .ic-input-text__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-input-text__field--secondary.ic-input-text__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.18);
  }

  /* Invalid state */
  .ic-input-text--invalid .ic-input-text__field {
    border-color: var(--ic-destructive);
  }

  .ic-input-text--invalid .ic-input-text__field--focused {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-input-text--invalid .ic-input-text__affix {
    color: var(--ic-destructive);
    border-color: var(--ic-destructive);
  }

  /* Disabled state */
  .ic-input-text--disabled .ic-input-text__field {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: var(--ic-muted);
  }

  /* Readonly state */
  .ic-input-text--readonly .ic-input-text__field {
    background-color: var(--ic-muted);
  }

  /* ===== INPUT ===== */
  .ic-input-text__input {
    flex: 1;
    min-width: 0;
    border: none;
    outline: none;
    background: transparent;
    color: var(--ic-foreground);
    font-family: inherit;
    font-size: inherit;
    line-height: 1;
  }

  .ic-input-text__input::placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  .ic-input-text__input:disabled {
    cursor: not-allowed;
  }

  /* ===== SIZES ===== */
  .ic-input-text--sm .ic-input-text__field { font-size: 0.75rem; }
  .ic-input-text--md .ic-input-text__field { font-size: 0.8125rem; }
  .ic-input-text--lg .ic-input-text__field { font-size: 0.9375rem; }

  .ic-input-text--sm .ic-input-text__input { padding: 0.25rem 0.375rem; }
  .ic-input-text--md .ic-input-text__input { padding: 0.375rem 0.5rem; }
  .ic-input-text--lg .ic-input-text__input { padding: 0.5rem 0.625rem; }

  /* ===== AFFIXES (prefix / suffix) ===== */
  .ic-input-text__affix {
    display: flex;
    align-items: center;
    color: var(--ic-muted-foreground);
    font-size: 0.85em;
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    user-select: none;
    background-color: var(--ic-secondary);
    border-color: var(--ic-border);
  }

  .ic-input-text__prefix {
    border-right: 1px solid var(--ic-border);
  }

  .ic-input-text__suffix {
    border-left: 1px solid var(--ic-border);
  }

  .ic-input-text--sm .ic-input-text__affix { padding: 0.25rem 0.375rem; }
  .ic-input-text--md .ic-input-text__affix { padding: 0.375rem 0.5rem; }
  .ic-input-text--lg .ic-input-text__affix { padding: 0.5rem 0.625rem; }

  /* ===== CLEAR BUTTON ===== */
  .ic-input-text__clear {
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0 0.375rem;
    flex-shrink: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease, color 0.15s ease;
  }

  .ic-input-text__clear:hover {
    opacity: 1;
    color: var(--ic-foreground);
  }

  /* ===== HELPER / ERROR TEXT ===== */
  .ic-input-text__helper,
  .ic-input-text__error,
  .ic-input-text__counter {
    font-size: 0.7rem;
    line-height: 1.2;
    padding: 0 0.125rem;
  }

  .ic-input-text__helper {
    color: var(--ic-muted-foreground);
  }

  .ic-input-text__error {
    color: var(--ic-destructive);
  }

  /* ===== CHARACTER COUNTER ===== */
  .ic-input-text__counter {
    color: var(--ic-muted-foreground);
    text-align: right;
    font-variant-numeric: tabular-nums;
    align-self: flex-end;
  }

  .ic-input-text__counter--warn {
    color: var(--ic-destructive);
  }
</style>
