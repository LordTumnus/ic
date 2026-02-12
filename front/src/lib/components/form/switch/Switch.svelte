<script lang="ts">
  import type { Resolution } from '$lib/types';
  import logger from '$lib/core/logger';

  let {
    value = $bindable('off'),
    variant = $bindable('primary'),
    shape = $bindable('square'),
    size = $bindable('md'),
    showLabel = $bindable(false),
    disabled = $bindable(false),
    valueChanged,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: string;
    variant?: string;
    shape?: string;
    size?: string;
    showLabel?: boolean;
    disabled?: boolean;
    valueChanged?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  let buttonEl: HTMLButtonElement;

  const isOn = $derived(value === 'on');

  $effect(() => {
    focus = (): Resolution => {
      buttonEl?.focus();
      return { success: true, data: null };
    };
  });

  function handleClick() {
    if (!disabled) {
      value = isOn ? 'off' : 'on';
      valueChanged?.({ value });
      logger.debug('Switch', 'toggled', { value });
    }
  }
</script>

<div
  class="ic-switch"
  class:ic-switch--sm={size === 'sm'}
  class:ic-switch--md={size === 'md'}
  class:ic-switch--lg={size === 'lg'}
  class:ic-switch--pill={shape === 'pill'}
  class:ic-switch--disabled={disabled}
>
  <button
    bind:this={buttonEl}
    class="ic-switch__track"
    class:ic-switch__track--on={isOn}
    class:ic-switch__track--primary={variant === 'primary'}
    class:ic-switch__track--secondary={variant === 'secondary'}
    class:ic-switch__track--destructive={variant === 'destructive'}
    role="switch"
    aria-checked={isOn}
    aria-label={isOn ? 'ON' : 'OFF'}
    {disabled}
    onclick={handleClick}
  >
    <span class="ic-switch__thumb"></span>
  </button>

  {#if showLabel}
    <span class="ic-switch__label" class:ic-switch__label--on={isOn}>
      {isOn ? 'ON' : 'OFF'}
    </span>
  {/if}
</div>

<style>
  .ic-switch {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
  }

  .ic-switch--disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ===== SIZE (controls label + track) ===== */
  .ic-switch--sm { font-size: 0.7rem; }
  .ic-switch--md { font-size: 0.75rem; }
  .ic-switch--lg { font-size: 0.85rem; }

  /* ===== LABEL (ON/OFF indicator) ===== */
  .ic-switch__label {
    font-family: inherit;
    font-weight: 600;
    letter-spacing: 0.05em;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    user-select: none;
    transition: color 0.25s ease;
  }

  .ic-switch__label--on {
    color: var(--ic-foreground);
  }

  /* ===== TRACK (recessed channel) ===== */
  .ic-switch__track {
    position: relative;
    border: none;
    border-radius: 3px;
    background-color: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    transition: background-color 0.25s ease, box-shadow 0.25s ease;
    outline: none;
  }

  .ic-switch__track:disabled {
    cursor: not-allowed;
  }

  /* Track sizes */
  .ic-switch--sm .ic-switch__track { width: 28px; height: 16px; }
  .ic-switch--md .ic-switch__track { width: 36px; height: 20px; }
  .ic-switch--lg .ic-switch__track { width: 44px; height: 24px; }

  /* Pill shape track */
  .ic-switch--pill .ic-switch__track { border-radius: 999px; }

  /* ===== THUMB (sliding knob) ===== */
  .ic-switch__thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    border-radius: 2px;
    background-color: var(--ic-muted-foreground);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.15),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
    transition: left 0.25s ease, background-color 0.25s ease;
  }

  /* Pill shape thumb */
  .ic-switch--pill .ic-switch__thumb { border-radius: 50%; }

  /* Thumb sizes */
  .ic-switch--sm .ic-switch__thumb { width: 12px; height: 12px; }
  .ic-switch--md .ic-switch__thumb { width: 16px; height: 16px; }
  .ic-switch--lg .ic-switch__thumb { width: 20px; height: 20px; }

  /* ===== ON STATE ===== */
  .ic-switch__track--on .ic-switch__thumb {
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* Thumb slide position when ON */
  .ic-switch--sm .ic-switch__track--on .ic-switch__thumb { left: 14px; }
  .ic-switch--md .ic-switch__track--on .ic-switch__thumb { left: 18px; }
  .ic-switch--lg .ic-switch__track--on .ic-switch__thumb { left: 22px; }

  /* ===== PRIMARY ON ===== */
  .ic-switch__track--primary.ic-switch__track--on {
    background-color: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.2);
  }

  .ic-switch__track--primary.ic-switch__track--on .ic-switch__thumb {
    background-color: var(--ic-primary-foreground);
  }

  /* ===== SECONDARY ON ===== */
  .ic-switch__track--secondary.ic-switch__track--on {
    background-color: var(--ic-muted-foreground);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.15);
  }

  .ic-switch__track--secondary.ic-switch__track--on .ic-switch__thumb {
    background-color: var(--ic-secondary);
  }

  /* ===== DESTRUCTIVE ON ===== */
  .ic-switch__track--destructive.ic-switch__track--on {
    background-color: var(--ic-destructive);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.2);
  }

  .ic-switch__track--destructive.ic-switch__track--on .ic-switch__thumb {
    background-color: var(--ic-destructive-foreground);
  }

  /* ===== HOVER ===== */
  .ic-switch__track:hover:not(:disabled) .ic-switch__thumb {
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* ===== FOCUS ===== */
  .ic-switch__track:focus-visible {
    box-shadow:
      inset 0 1px 3px rgba(0, 0, 0, 0.2),
      0 0 6px rgba(0, 0, 0, 0.15);
  }

  .ic-switch__track--on:focus-visible {
    box-shadow:
      inset 0 2px 4px rgba(0, 0, 0, 0.25),
      0 0 6px rgba(0, 0, 0, 0.15);
  }
</style>
