<script lang="ts">
  import { resolveIcon } from '$lib/utils/icons';

  const ICON_SIZES: Record<string, number> = { sm: 10, md: 12, lg: 14 };

  let {
    label,
    icon = '',
    size = 'md',
    disabled = false,
    active = false,
    removing = false,
    onremove,
  }: {
    label: string;
    icon?: string;
    size?: string;
    disabled?: boolean;
    active?: boolean;
    removing?: boolean;
    onremove?: () => void;
  } = $props();

  // Resolve icon SVG
  const iconSvg = $derived(resolveIcon(icon, ICON_SIZES[size] ?? 12));

  function handleRemoveClick(e: MouseEvent) {
    e.stopPropagation();
    e.preventDefault();
    if (!disabled) onremove?.();
  }

  function handleAnimationEnd() {
    if (removing) onremove?.();
  }
</script>

<span
  class="ic-tag"
  class:ic-tag--sm={size === 'sm'}
  class:ic-tag--md={size === 'md'}
  class:ic-tag--lg={size === 'lg'}
  class:ic-tag--active={active}
  class:ic-tag--disabled={disabled}
  class:ic-tag--removing={removing}
  onanimationend={handleAnimationEnd}
>
  {#if iconSvg}
    <span class="ic-tag__icon">{@html iconSvg}</span>
  {/if}

  <span class="ic-tag__label">{label}</span>

  {#if !disabled && onremove}
    <button
      class="ic-tag__remove"
      tabindex={-1}
      aria-label="Remove {label}"
      onmousedown={handleRemoveClick}
    >
      <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
        <path d="M7.5 2.5L2.5 7.5M2.5 2.5L7.5 7.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    </button>
  {/if}
</span>

<style>
  .ic-tag {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background-color: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
    white-space: nowrap;
    user-select: none;
    max-width: 150px;
    transition: border-color 0.12s ease, box-shadow 0.12s ease;
  }

  /* Sizes */
  .ic-tag--sm { font-size: 0.7rem; padding: 1px 5px; gap: 3px; }
  .ic-tag--md { font-size: 0.8rem; padding: 2px 7px; gap: 4px; }
  .ic-tag--lg { font-size: 0.85rem; padding: 3px 9px; gap: 5px; }

  /* Active (keyboard-focused) */
  .ic-tag--active {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
  }

  /* Disabled */
  .ic-tag--disabled {
    opacity: 0.5;
    cursor: default;
  }

  /* Icon */
  .ic-tag__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }

  /* Label */
  .ic-tag__label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    line-height: 1.2;
  }

  /* Remove button */
  .ic-tag__remove {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    border-radius: 50%;
    width: 12px;
    height: 12px;
    opacity: 0.7;
    transition: opacity 0.12s ease, color 0.12s ease, background-color 0.12s ease;
    line-height: 0;
  }
  .ic-tag__remove svg { width: 8px; height: 8px; }
  .ic-tag--sm .ic-tag__remove { width: 10px; height: 10px; }
  .ic-tag--sm .ic-tag__remove svg { width: 7px; height: 7px; }
  .ic-tag--lg .ic-tag__remove { width: 14px; height: 14px; }
  .ic-tag--lg .ic-tag__remove svg { width: 9px; height: 9px; }

  .ic-tag__remove:hover {
    opacity: 1;
    background-color: rgba(220, 50, 50, 0.15);
    color: var(--ic-destructive);
  }

  /* Remove animation */
  @keyframes ic-tag-remove {
    to {
      opacity: 0;
      transform: scaleX(0);
    }
  }
  .ic-tag--removing {
    transform-origin: left center;
    animation: ic-tag-remove 100ms ease-out forwards;
    pointer-events: none;
  }
</style>
