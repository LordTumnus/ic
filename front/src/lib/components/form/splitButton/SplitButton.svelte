<script lang="ts">
  import type { Resolution, ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';
  import { computeDropdownPosition, dropdownStyle } from '$lib/utils/dropdown-position';

  let {
    id = '',
    items = $bindable<string[] | string>([]),
    itemDescriptions = $bindable<string[] | string>([]),
    variant = $bindable('primary'),
    fill = $bindable('solid'),
    size = $bindable('md'),
    disabled = $bindable(false),
    splitDirection = $bindable('right'),
    iconMap = $bindable<Record<string, string>>({}),
    childEntries = [] as ChildEntries,
    itemSelected,
    opened,
    closed,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    items?: string[] | string;
    itemDescriptions?: string[] | string;
    variant?: string;
    fill?: string;
    size?: string;
    disabled?: boolean;
    splitDirection?: string;
    iconMap?: Record<string, string>;
    childEntries?: ChildEntries;
    itemSelected?: (data?: unknown) => void;
    opened?: (data?: unknown) => void;
    closed?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  // --- Refs & state ---
  let mainBtnEl: HTMLButtonElement;
  let rootEl: HTMLDivElement;
  let isOpen = $state(false);
  let mainFocused = $state(false);
  let triggerFocused = $state(false);

  // --- Derived ---
  const itemList = $derived(
    Array.isArray(items) ? items : items ? [items] : []
  );
  const descList = $derived(
    Array.isArray(itemDescriptions) ? itemDescriptions : itemDescriptions ? [itemDescriptions] : []
  );
  const mainLabel = $derived(itemList[0] ?? '');
  const bodyFocused = $derived(mainFocused || triggerFocused);
  const iconEntries = $derived(childEntries.filter(c => c.type === 'ic.Icon' || c.type === 'ic.Image'));
  const hasMainIcon = $derived(iconEntries.length > 0);
  const chevronSize = $derived(size === 'sm' ? 10 : size === 'lg' ? 14 : 12);

  function getItemIconEntry(item: string) {
    const iconId = iconMap?.[item];
    if (!iconId) return null;
    return childEntries.find(c => c.id === iconId) ?? null;
  }

  function hasItemIcon(item: string): boolean {
    return getItemIconEntry(item) !== null;
  }

  // --- Focus method ---
  $effect(() => {
    focus = (): Resolution => {
      mainBtnEl?.focus();
      return { success: true, data: null };
    };
  });

  // --- Cleanup listener on destroy ---
  $effect(() => {
    return () => {
      document.removeEventListener('pointerdown', handleClickOutside);
    };
  });

  // --- Handlers ---
  function handleMainClick() {
    if (disabled) return;
    itemSelected?.({ index: 1, label: mainLabel });
  }

  function togglePopup() {
    if (disabled) return;
    isOpen = !isOpen;
    if (isOpen) {
      opened?.();
      requestAnimationFrame(() => {
        document.addEventListener('pointerdown', handleClickOutside);
      });
    } else {
      closed?.();
      document.removeEventListener('pointerdown', handleClickOutside);
    }
  }

  function closePopup() {
    if (!isOpen) return;
    isOpen = false;
    closed?.();
    document.removeEventListener('pointerdown', handleClickOutside);
  }

  function handleClickOutside(e: PointerEvent) {
    if (rootEl && !rootEl.contains(e.target as Node)) {
      closePopup();
    }
  }

  function handleItemClick(i: number) {
    itemSelected?.({ index: i + 1, label: itemList[i] });
    closePopup();
  }

  function handleTriggerKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      togglePopup();
    } else if (e.key === 'Escape') {
      closePopup();
    }
  }

  function handleItemKeydown(e: KeyboardEvent, i: number) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleItemClick(i);
    } else if (e.key === 'Escape') {
      closePopup();
    }
  }

  // Compute fixed position when popup opens
  let ddPos = $state('');
  $effect(() => {
    if (isOpen && rootEl) {
      const pos = computeDropdownPosition(rootEl, { offset: 3, matchWidth: false });
      ddPos = dropdownStyle(pos);
    }
  });
</script>

<div {id}
  bind:this={rootEl}
  class="ic-split-btn"
  class:ic-split-btn--right={splitDirection === 'right'}
  class:ic-split-btn--bottom={splitDirection === 'bottom'}
  class:ic-split-btn--disabled={disabled}
  class:ic-split-btn--open={isOpen}
>
  <div
    class="ic-split-btn__body"
    class:ic-split-btn__body--primary={variant === 'primary'}
    class:ic-split-btn__body--secondary={variant === 'secondary'}
    class:ic-split-btn__body--destructive={variant === 'destructive'}
    class:ic-split-btn__body--solid={fill === 'solid'}
    class:ic-split-btn__body--outline={fill === 'outline'}
    class:ic-split-btn__body--ghost={fill === 'ghost'}
    class:ic-split-btn__body--sm={size === 'sm'}
    class:ic-split-btn__body--md={size === 'md'}
    class:ic-split-btn__body--lg={size === 'lg'}
    class:ic-split-btn__body--focused={bodyFocused}
  >
    <!-- Main button -->
    <button
      bind:this={mainBtnEl}
      class="ic-split-btn__main"
      {disabled}
      onclick={handleMainClick}
      onfocus={() => (mainFocused = true)}
      onblur={() => (mainFocused = false)}
    >
      {#if hasMainIcon}
        <span class="ic-split-btn__icon">
          {#each iconEntries as iconSnippet (iconSnippet.id)}
            <DynamicChild entry={iconSnippet} />
          {/each}
        </span>
      {/if}
      {#if mainLabel}
        <span class="ic-split-btn__label">{mainLabel}</span>
      {/if}
    </button>

    <!-- Chevron trigger -->
    <button
      class="ic-split-btn__trigger"
      {disabled}
      onclick={togglePopup}
      onkeydown={handleTriggerKeydown}
      onfocus={() => (triggerFocused = true)}
      onblur={() => (triggerFocused = false)}
      aria-expanded={isOpen}
      aria-label="Show more actions"
    >
      <svg
        class="ic-split-btn__chevron"
        width={chevronSize}
        height={chevronSize}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <polyline points="6 9 12 15 18 9"></polyline>
      </svg>
    </button>
  </div>

  <!-- Dropdown popup -->
  {#if isOpen}
    <div class="ic-split-btn__popup" style={ddPos}>
      {#each itemList as item, i (item)}
        {@const hasDesc = !!descList[i]}
        <button
          class="ic-split-btn__item"
          onclick={() => handleItemClick(i)}
          onkeydown={(e) => handleItemKeydown(e, i)}
        >
          {#if hasItemIcon(item)}
            {@const itemIconEntry = getItemIconEntry(item)}
            <span class="ic-split-btn__item-icon">
              {#if itemIconEntry}
                <DynamicChild entry={itemIconEntry} />
              {/if}
            </span>
          {/if}
          <div class="ic-split-btn__item-text">
            <span class="ic-split-btn__item-label">{item}</span>
            {#if hasDesc}
              <span class="ic-split-btn__item-desc">{descList[i]}</span>
            {/if}
          </div>
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-split-btn {
    display: inline-flex;
    flex-direction: column;
    position: relative;
    font-family: inherit;
  }

  /* ===== BODY (joined main + trigger) ===== */
  .ic-split-btn__body {
    display: inline-flex;
    border: 1.5px solid transparent;
    border-radius: 2px;
    overflow: hidden;
    transition: border-color 0.15s ease, box-shadow 0.15s ease, filter 0.1s ease;
  }

  .ic-split-btn--right .ic-split-btn__body {
    flex-direction: row;
  }

  .ic-split-btn--bottom .ic-split-btn__body {
    flex-direction: column;
  }

  /* ===== MAIN BUTTON ===== */
  .ic-split-btn__main {
    display: inline-flex;
    align-items: center;
    justify-content: flex-start;
    gap: 0.375rem;
    border: none;
    background: transparent;
    color: inherit;
    font-family: inherit;
    font-weight: 500;
    cursor: pointer;
    outline: none;
    flex: 1 1 auto;
    min-width: 0;
    transition: background-color 0.1s ease;
  }

  .ic-split-btn--bottom .ic-split-btn__main {
    flex-direction: column;
  }

  /* ===== TRIGGER ===== */
  .ic-split-btn__trigger {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: inherit;
    cursor: pointer;
    outline: none;
    flex-shrink: 0;
    transition: background-color 0.1s ease;
  }

  /* Separator: right direction — groove effect */
  .ic-split-btn--right .ic-split-btn__trigger {
    border-left: 1px solid rgba(0, 0, 0, 0.2);
    box-shadow: inset 1px 0 0 rgba(255, 255, 255, 0.08);
  }

  /* Separator: bottom direction — groove effect */
  .ic-split-btn--bottom .ic-split-btn__trigger {
    border-top: 1px solid rgba(0, 0, 0, 0.2);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
  }

  /* ===== SIZE: main button padding ===== */
  .ic-split-btn__body--sm .ic-split-btn__main { padding: 0.25rem 0.5rem 0.25rem 0.35rem; }
  .ic-split-btn__body--md .ic-split-btn__main { padding: 0.375rem 0.75rem 0.375rem 0.5rem; }
  .ic-split-btn__body--lg .ic-split-btn__main { padding: 0.5rem 1rem 0.5rem 0.65rem; }

  /* ===== SIZE: trigger padding (right) ===== */
  .ic-split-btn--right .ic-split-btn__body--sm .ic-split-btn__trigger { padding: 0.25rem 0.3rem; }
  .ic-split-btn--right .ic-split-btn__body--md .ic-split-btn__trigger { padding: 0.375rem 0.4rem; }
  .ic-split-btn--right .ic-split-btn__body--lg .ic-split-btn__trigger { padding: 0.5rem 0.5rem; }

  /* ===== SIZE: trigger padding (bottom) ===== */
  .ic-split-btn--bottom .ic-split-btn__trigger { padding: 0.125rem; }

  /* ===== FONT SIZES ===== */
  .ic-split-btn__body--sm .ic-split-btn__label { font-size: 0.75rem; }
  .ic-split-btn__body--md .ic-split-btn__label { font-size: 0.8125rem; }
  .ic-split-btn__body--lg .ic-split-btn__label { font-size: 0.875rem; }

  /* ===== PRIMARY + SOLID ===== */
  .ic-split-btn__body--primary.ic-split-btn__body--solid {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
    border-color: var(--ic-primary);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.12);
  }

  /* PRIMARY + OUTLINE */
  .ic-split-btn__body--primary.ic-split-btn__body--outline {
    background-color: var(--ic-background);
    color: var(--ic-primary);
    border-color: var(--ic-primary);
    box-shadow:
      0 1px 2px rgba(0, 0, 0, 0.1),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  /* PRIMARY + GHOST */
  .ic-split-btn__body--primary.ic-split-btn__body--ghost {
    background-color: transparent;
    color: var(--ic-primary);
  }

  /* ===== SECONDARY + SOLID ===== */
  .ic-split-btn__body--secondary.ic-split-btn__body--solid {
    background-color: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    border-color: var(--ic-border);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.15),
      inset 0 1px 0 rgba(255, 255, 255, 0.08);
  }

  /* SECONDARY + OUTLINE */
  .ic-split-btn__body--secondary.ic-split-btn__body--outline {
    background-color: var(--ic-background);
    color: var(--ic-secondary-foreground);
    border-color: var(--ic-border);
    box-shadow:
      0 1px 2px rgba(0, 0, 0, 0.1),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  /* SECONDARY + GHOST */
  .ic-split-btn__body--secondary.ic-split-btn__body--ghost {
    background-color: transparent;
    color: var(--ic-secondary-foreground);
  }

  /* ===== DESTRUCTIVE + SOLID ===== */
  .ic-split-btn__body--destructive.ic-split-btn__body--solid {
    background-color: var(--ic-destructive);
    color: var(--ic-destructive-foreground);
    border-color: var(--ic-destructive);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.12);
  }

  /* DESTRUCTIVE + OUTLINE */
  .ic-split-btn__body--destructive.ic-split-btn__body--outline {
    background-color: var(--ic-background);
    color: var(--ic-destructive);
    border-color: var(--ic-destructive);
    box-shadow:
      0 1px 2px rgba(0, 0, 0, 0.1),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  /* DESTRUCTIVE + GHOST */
  .ic-split-btn__body--destructive.ic-split-btn__body--ghost {
    background-color: transparent;
    color: var(--ic-destructive);
  }

  /* ===== OPEN STATE (trigger pressed-in) ===== */
  .ic-split-btn--open .ic-split-btn__body--solid .ic-split-btn__trigger {
    background-color: rgba(0, 0, 0, 0.12);
  }

  .ic-split-btn--open .ic-split-btn__body--outline .ic-split-btn__trigger,
  .ic-split-btn--open .ic-split-btn__body--ghost .ic-split-btn__trigger {
    background-color: rgba(0, 0, 0, 0.06);
  }

  /* ===== HOVER ===== */
  .ic-split-btn__body--solid .ic-split-btn__main:hover:not(:disabled),
  .ic-split-btn__body--solid .ic-split-btn__trigger:hover:not(:disabled) {
    background-color: rgba(0, 0, 0, 0.08);
  }

  .ic-split-btn__body--outline .ic-split-btn__main:hover:not(:disabled),
  .ic-split-btn__body--outline .ic-split-btn__trigger:hover:not(:disabled) {
    background-color: var(--ic-muted);
  }

  .ic-split-btn__body--ghost .ic-split-btn__main:hover:not(:disabled),
  .ic-split-btn__body--ghost .ic-split-btn__trigger:hover:not(:disabled) {
    background-color: var(--ic-muted);
  }

  /* ===== FOCUS ===== */
  .ic-split-btn__body--focused {
    border-color: var(--ic-primary);
  }

  .ic-split-btn__body--focused.ic-split-btn__body--solid {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.3),
      inset 0 1px 0 rgba(255, 255, 255, 0.12);
  }

  .ic-split-btn__body--focused.ic-split-btn__body--outline,
  .ic-split-btn__body--focused.ic-split-btn__body--ghost {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  /* ===== DISABLED ===== */
  .ic-split-btn--disabled .ic-split-btn__body {
    opacity: 0.5;
  }

  .ic-split-btn--disabled .ic-split-btn__main,
  .ic-split-btn--disabled .ic-split-btn__trigger {
    cursor: not-allowed;
  }

  /* ===== CHILDREN ===== */
  .ic-split-btn__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
  }

  .ic-split-btn__label {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    letter-spacing: 0.01em;
  }

  /* ===== POPUP ===== */
  .ic-split-btn__popup {
    position: fixed;
    z-index: 50;
    width: max-content;
    background-color: var(--ic-background);
    border: 1.5px solid var(--ic-border);
    border-radius: 2px;
    box-shadow:
      0 2px 8px rgba(0, 0, 0, 0.2),
      0 0 0 1px rgba(0, 0, 0, 0.04);
    overflow: hidden;
  }

  /* ===== POPUP ITEMS ===== */
  .ic-split-btn__item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0.5rem 0.75rem;
    border: none;
    background: transparent;
    color: var(--ic-foreground);
    font-family: inherit;
    cursor: pointer;
    text-align: left;
    outline: none;
    transition: background-color 0.1s ease, box-shadow 0.1s ease;
  }

  .ic-split-btn__item + .ic-split-btn__item {
    border-top: 1px solid var(--ic-border);
  }

  .ic-split-btn__item:hover {
    background-color: var(--ic-accent);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
  }

  .ic-split-btn__item:active {
    background-color: var(--ic-accent);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  .ic-split-btn__item:focus-visible {
    background-color: var(--ic-accent);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
  }

  /* ===== ITEM CHILDREN ===== */
  .ic-split-btn__item-icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
  }

  .ic-split-btn__item-text {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .ic-split-btn__item-label {
    font-weight: 500;
    font-size: 0.8125rem;
    white-space: nowrap;
    color: var(--ic-foreground);
    letter-spacing: 0.01em;
  }

  .ic-split-btn__item-desc {
    font-size: 0.6875rem;
    font-weight: 400;
    color: var(--ic-muted-foreground);
    line-height: 1.3;
    white-space: normal;
    letter-spacing: 0.01em;
  }
</style>
