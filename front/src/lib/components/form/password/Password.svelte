<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution } from '$lib/types';
  import logger from '$lib/core/logger';
  import eyeRaw from 'lucide-static/icons/eye.svg?raw';
  import eyeOffRaw from 'lucide-static/icons/eye-off.svg?raw';
  import lockRaw from 'lucide-static/icons/lock-keyhole.svg?raw';

  // Resize Lucide SVGs (24x24 default) to fit our component
  function resizeIcon(svg: string, size: number): string {
    return svg
      .replace(/width="24"/, `width="${size}"`)
      .replace(/height="24"/, `height="${size}"`);
  }

  const lockIcon = $derived(resizeIcon(lockRaw, 14));
  const toggleIcon = $derived(resizeIcon(revealed ? eyeOffRaw : eyeRaw, 16));

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
    showToggle = $bindable(true),
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
    showToggle?: boolean;
    valueChanged?: (data?: unknown) => void;
    submitted?: (data?: unknown) => void;
    focus?: () => Resolution;
    blur?: () => Resolution;
    selectAll?: () => Resolution;
    clear?: () => Resolution;
  } = $props();

  let inputEl: HTMLInputElement;
  let revealed = $state(false);
  let focused = $state(false);

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
      logger.debug('Password', 'cleared');
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

  function toggleReveal() {
    revealed = !revealed;
    inputEl?.focus();
  }
</script>

<div {id}
  class="ic-password"
  class:ic-password--sm={size === 'sm'}
  class:ic-password--md={size === 'md'}
  class:ic-password--lg={size === 'lg'}
  class:ic-password--disabled={disabled}
  class:ic-password--invalid={invalid}
  class:ic-password--readonly={readonly}
>
  <div
    class="ic-password__field"
    class:ic-password__field--primary={variant === 'primary'}
    class:ic-password__field--secondary={variant === 'secondary'}
    class:ic-password__field--focused={focused}
  >
    <!-- Lock icon prefix -->
    <span class="ic-password__lock">
      {@html lockIcon}
    </span>

    <input
      bind:this={inputEl}
      class="ic-password__input"
      type={revealed ? 'text' : 'password'}
      value={value}
      {placeholder}
      {disabled}
      readonly={readonly}
      aria-invalid={invalid || undefined}
      oninput={handleInput}
      onkeydown={handleKeydown}
      onfocus={() => { focused = true; }}
      onblur={() => { focused = false; }}
    />

    {#if showToggle && !disabled}
      <button
        class="ic-password__toggle"
        class:ic-password__toggle--revealed={revealed}
        tabindex="-1"
        aria-label={revealed ? 'Hide password' : 'Show password'}
        onmousedown={(e) => e.preventDefault()}
        onclick={toggleReveal}
      >
        {@html toggleIcon}
      </button>
    {/if}
  </div>

  {#if invalid && errorMessage}
    <span class="ic-password__error">{errorMessage}</span>
  {:else if helperText}
    <span class="ic-password__helper">{helperText}</span>
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-password {
    display: inline-flex;
    flex-direction: column;
    gap: 0.25rem;
    font-family: inherit;
    width: 100%;
  }

  /* ===== FIELD WRAPPER (recessed channel) ===== */
  .ic-password__field {
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
  .ic-password__field--primary {
    border-color: var(--ic-border);
  }

  /* Secondary variant - more recessed */
  .ic-password__field--secondary {
    background-color: var(--ic-secondary);
    border-color: transparent;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  /* Focus state */
  .ic-password__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-password__field--secondary.ic-password__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.18);
  }

  /* Invalid state */
  .ic-password--invalid .ic-password__field {
    border-color: var(--ic-destructive);
  }

  .ic-password--invalid .ic-password__field--focused {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  /* Disabled state */
  .ic-password--disabled .ic-password__field {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: var(--ic-muted);
  }

  /* Readonly state */
  .ic-password--readonly .ic-password__field {
    background-color: var(--ic-muted);
  }

  /* ===== LOCK ICON ===== */
  .ic-password__lock {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--ic-muted-foreground);
    flex-shrink: 0;
    opacity: 0.6;
  }

  .ic-password--sm .ic-password__lock { padding: 0 0 0 0.375rem; }
  .ic-password--md .ic-password__lock { padding: 0 0 0 0.5rem; }
  .ic-password--lg .ic-password__lock { padding: 0 0 0 0.625rem; }

  .ic-password--invalid .ic-password__lock {
    color: var(--ic-destructive);
  }

  /* ===== INPUT ===== */
  .ic-password__input {
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

  .ic-password__input::placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  .ic-password__input:disabled {
    cursor: not-allowed;
  }

  /* ===== SIZES ===== */
  .ic-password--sm .ic-password__field { font-size: 0.75rem; }
  .ic-password--md .ic-password__field { font-size: 0.8125rem; }
  .ic-password--lg .ic-password__field { font-size: 0.9375rem; }

  .ic-password--sm .ic-password__input { padding: 0.25rem 0.375rem; }
  .ic-password--md .ic-password__input { padding: 0.375rem 0.5rem; }
  .ic-password--lg .ic-password__input { padding: 0.5rem 0.625rem; }

  /* ===== TOGGLE BUTTON ===== */
  .ic-password__toggle {
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    flex-shrink: 0;
    opacity: 0.45;
    transition: opacity 0.15s ease, color 0.15s ease;
  }

  .ic-password--sm .ic-password__toggle { padding: 0.25rem 0.375rem; }
  .ic-password--md .ic-password__toggle { padding: 0.375rem 0.5rem; }
  .ic-password--lg .ic-password__toggle { padding: 0.5rem 0.625rem; }

  .ic-password__toggle:hover {
    opacity: 0.85;
    color: var(--ic-foreground);
  }

  .ic-password__toggle--revealed {
    opacity: 0.7;
    color: var(--ic-primary);
  }

  .ic-password__toggle--revealed:hover {
    opacity: 1;
    color: var(--ic-primary);
  }

  /* ===== HELPER / ERROR TEXT ===== */
  .ic-password__helper,
  .ic-password__error {
    font-size: 0.7rem;
    line-height: 1.2;
    padding: 0 0.125rem;
  }

  .ic-password__helper {
    color: var(--ic-muted-foreground);
  }

  .ic-password__error {
    color: var(--ic-destructive);
  }
</style>
