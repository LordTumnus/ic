<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution } from '$lib/types';
  import logger from '$lib/core/logger';

  let {
    value = $bindable(''),
    placeholder = $bindable(''),
    variant = $bindable('primary'),
    size = $bindable('md'),
    disabled = $bindable(false),
    readonly = $bindable(false),
    invalid = $bindable(false),
    errorMessage = $bindable(''),
    helperText = $bindable(''),
    rows = $bindable(4),
    resize = $bindable('vertical'),
    autoResize = $bindable(false),
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
    value?: string;
    placeholder?: string;
    variant?: string;
    size?: string;
    disabled?: boolean;
    readonly?: boolean;
    invalid?: boolean;
    errorMessage?: string;
    helperText?: string;
    rows?: number;
    resize?: string;
    autoResize?: boolean;
    maxLength?: number;
    showCounter?: boolean;
    valueChanged?: (data?: unknown) => void;
    submitted?: (data?: unknown) => void;
    focus?: () => Resolution;
    blur?: () => Resolution;
    selectAll?: () => Resolution;
    clear?: () => Resolution;
  } = $props();

  let textareaEl: HTMLTextAreaElement;

  // Derived
  const charCount = $derived(value.length);
  const showCharCounter = $derived(showCounter && maxLength > 0);
  const isNearLimit = $derived(maxLength > 0 && charCount >= maxLength * 0.9);

  // Resolve CSS resize value
  const resizeValue = $derived(
    autoResize ? 'none' : resize === 'both' ? 'both' : resize === 'horizontal' ? 'horizontal' : resize === 'none' ? 'none' : 'vertical'
  );

  // Force reflow when rows changes (Chromium 104 doesn't reflow on attribute-only changes)
  $effect(() => {
    if (textareaEl) {
      void rows;
      void textareaEl.offsetHeight;
    }
  });

  // Auto-resize: adjust height to content
  $effect(() => {
    if (autoResize && textareaEl) {
      void value;
      void rows;
      textareaEl.style.height = 'auto';
      textareaEl.style.height = textareaEl.scrollHeight + 'px';
    }
  });

  // Methods
  onMount(() => {
    focus = (): Resolution => {
      textareaEl?.focus();
      return { success: true, data: null };
    };

    blur = (): Resolution => {
      textareaEl?.blur();
      return { success: true, data: null };
    };

    selectAll = (): Resolution => {
      textareaEl?.focus();
      textareaEl?.select();
      return { success: true, data: null };
    };

    clear = (): Resolution => {
      value = '';
      valueChanged?.({ value: '' });
      logger.debug('TextArea', 'cleared');
      return { success: true, data: null };
    };
  });

  function handleInput(e: Event) {
    const target = e.currentTarget as HTMLTextAreaElement;
    value = target.value;
    valueChanged?.({ value: target.value });
  }

  function handleKeydown(e: KeyboardEvent) {
    // Ctrl+Enter or Cmd+Enter to submit
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
      submitted?.({ value });
    }
  }
</script>

<div
  class="ic-textarea"
  class:ic-textarea--sm={size === 'sm'}
  class:ic-textarea--md={size === 'md'}
  class:ic-textarea--lg={size === 'lg'}
  class:ic-textarea--disabled={disabled}
  class:ic-textarea--invalid={invalid}
  class:ic-textarea--readonly={readonly}
>
  <div
    class="ic-textarea__field"
    class:ic-textarea__field--primary={variant === 'primary'}
    class:ic-textarea__field--secondary={variant === 'secondary'}
    class:ic-textarea__field--focused={false}
  >
    <textarea
      bind:this={textareaEl}
      class="ic-textarea__input"
      value={value}
      {placeholder}
      {disabled}
      readonly={readonly}
      rows={rows}
      maxlength={maxLength > 0 ? maxLength : undefined}
      aria-invalid={invalid || undefined}
      style:resize={resizeValue}
      oninput={handleInput}
      onkeydown={handleKeydown}
      onfocus={() => {
        const field = textareaEl?.parentElement;
        if (field) field.classList.add('ic-textarea__field--focused');
      }}
      onblur={() => {
        const field = textareaEl?.parentElement;
        if (field) field.classList.remove('ic-textarea__field--focused');
      }}
    ></textarea>
  </div>

  {#if invalid && errorMessage}
    <span class="ic-textarea__error">{errorMessage}</span>
  {:else if helperText}
    <span class="ic-textarea__helper">{helperText}</span>
  {/if}

  {#if showCharCounter}
    <span class="ic-textarea__counter" class:ic-textarea__counter--warn={isNearLimit}>
      {charCount}/{maxLength}
    </span>
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-textarea {
    display: inline-flex;
    flex-direction: column;
    gap: 0.25rem;
    font-family: inherit;
    width: 100%;
  }

  /* ===== FIELD WRAPPER (recessed channel) ===== */
  .ic-textarea__field {
    display: flex;
    border-radius: 3px;
    border: 1px solid var(--ic-border);
    background-color: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  /* Primary variant */
  .ic-textarea__field--primary {
    border-color: var(--ic-border);
  }

  /* Secondary variant - more recessed */
  .ic-textarea__field--secondary {
    background-color: var(--ic-secondary);
    border-color: transparent;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  /* Focus state */
  .ic-textarea__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-textarea__field--secondary.ic-textarea__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.18);
  }

  /* Invalid state */
  .ic-textarea--invalid .ic-textarea__field {
    border-color: var(--ic-destructive);
  }

  .ic-textarea--invalid .ic-textarea__field--focused {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  /* Disabled state */
  .ic-textarea--disabled .ic-textarea__field {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: var(--ic-muted);
  }

  /* Readonly state */
  .ic-textarea--readonly .ic-textarea__field {
    background-color: var(--ic-muted);
  }

  /* ===== TEXTAREA ===== */
  .ic-textarea__input {
    flex: 1;
    min-width: 0;
    border: none;
    outline: none;
    background: transparent;
    color: var(--ic-foreground);
    font-family: inherit;
    font-size: inherit;
    line-height: 1.4;
    resize: vertical;
  }

  .ic-textarea__input::placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  .ic-textarea__input:disabled {
    cursor: not-allowed;
  }

  /* ===== SIZES ===== */
  .ic-textarea--sm .ic-textarea__field { font-size: 0.75rem; }
  .ic-textarea--md .ic-textarea__field { font-size: 0.8125rem; }
  .ic-textarea--lg .ic-textarea__field { font-size: 0.9375rem; }

  .ic-textarea--sm .ic-textarea__input { padding: 0.25rem 0.375rem; }
  .ic-textarea--md .ic-textarea__input { padding: 0.375rem 0.5rem; }
  .ic-textarea--lg .ic-textarea__input { padding: 0.5rem 0.625rem; }

  /* ===== HELPER / ERROR TEXT ===== */
  .ic-textarea__helper,
  .ic-textarea__error,
  .ic-textarea__counter {
    font-size: 0.7rem;
    line-height: 1.2;
    padding: 0 0.125rem;
  }

  .ic-textarea__helper {
    color: var(--ic-muted-foreground);
  }

  .ic-textarea__error {
    color: var(--ic-destructive);
  }

  /* ===== CHARACTER COUNTER ===== */
  .ic-textarea__counter {
    color: var(--ic-muted-foreground);
    text-align: right;
    font-variant-numeric: tabular-nums;
    align-self: flex-end;
  }

  .ic-textarea__counter--warn {
    color: var(--ic-destructive);
  }
</style>
