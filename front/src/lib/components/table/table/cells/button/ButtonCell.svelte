<script lang="ts">
  import type { ButtonConfig, CellButtonDef } from '$lib/utils/table-utils';
  import type { IconSource } from '$lib/utils/icons';
  import Icon from '$lib/components/display/icon/Icon.svelte';

  let {
    value,
    config = {} as Partial<ButtonConfig>,
    style = $bindable(''),
    oncellaction,
  }: {
    value?: unknown;
    config?: Partial<ButtonConfig>;
    style?: string;
    oncellaction?: (data: unknown) => void;
  } = $props();

  const buttons = $derived(config.buttons ?? []);
  const hasText = $derived(value != null && value !== '');
  const text = $derived(hasText ? String(value) : '');

  function handleClick(e: MouseEvent, btn: CellButtonDef) {
    e.stopPropagation();
    if (btn.disabled) return;
    oncellaction?.({ action: btn.key });
  }

  // No cell background tinting for button columns
  $effect(() => { style = ''; });
</script>

<span class="ic-tbl-cell-btn">
  {#if hasText}
    <span class="ic-tbl-cell-btn__text" title={text}>{text}</span>
  {/if}
  {#if buttons.length > 0}
    <span class="ic-tbl-cell-btn__group">
      {#each buttons as btn (btn.key)}
        <button
          class="ic-tbl-cell-btn__action"
          class:ic-tbl-cell-btn__action--primary={btn.variant === 'primary'}
          class:ic-tbl-cell-btn__action--destructive={btn.variant === 'destructive'}
          class:ic-tbl-cell-btn__action--disabled={btn.disabled}
          title={btn.tooltip || btn.label || btn.key}
          disabled={btn.disabled}
          onclick={(e: MouseEvent) => handleClick(e, btn)}
        >
          {#if btn.icon}
            <Icon source={btn.icon as IconSource} size={12} strokeWidth={2} />
          {/if}
          {#if btn.label}
            <span class="ic-tbl-cell-btn__label">{btn.label}</span>
          {/if}
        </button>
      {/each}
    </span>
  {/if}
</span>

<style>
  .ic-tbl-cell-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    min-width: 0;
  }

  .ic-tbl-cell-btn__text {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1 1 auto;
    min-width: 0;
  }

  .ic-tbl-cell-btn__group {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    flex-shrink: 0;
  }

  .ic-tbl-cell-btn__action {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    padding: 1px 5px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-secondary);
    color: var(--ic-foreground);
    font-size: 0.7rem;
    font-weight: 500;
    line-height: 1.4;
    cursor: pointer;
    white-space: nowrap;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
    transition: background-color 0.08s ease, box-shadow 0.08s ease;
  }
  .ic-tbl-cell-btn__action:hover {
    background: var(--ic-muted);
  }
  .ic-tbl-cell-btn__action:active {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.15);
  }

  /* Primary variant */
  .ic-tbl-cell-btn__action--primary {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    border-color: var(--ic-primary);
  }
  .ic-tbl-cell-btn__action--primary:hover {
    background: var(--ic-primary);
    box-shadow: inset 0 0 0 100px rgba(255, 255, 255, 0.12);
  }

  /* Destructive variant */
  .ic-tbl-cell-btn__action--destructive {
    background: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
    border-color: var(--ic-destructive);
  }
  .ic-tbl-cell-btn__action--destructive:hover {
    background: var(--ic-destructive);
    box-shadow: inset 0 0 0 100px rgba(255, 255, 255, 0.12);
  }

  /* Disabled */
  .ic-tbl-cell-btn__action--disabled {
    opacity: 0.4;
    pointer-events: none;
    cursor: default;
  }

  .ic-tbl-cell-btn__label {
    pointer-events: none;
  }
</style>
