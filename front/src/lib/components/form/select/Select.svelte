<script lang="ts">
  import type { Resolution } from '$lib/types';

  let {
    items = $bindable(['Option 1', 'Option 2', 'Option 3']),
    value = $bindable<string | null>(null),
    placeholder = $bindable('Select...'),
    disabled = $bindable(false),
    invalid = $bindable(false),
    errorMessage = $bindable(''),
    helperText = $bindable(''),
    clearable = $bindable(false),
    searchable = $bindable(false),
    size = $bindable('md'),
    variant = $bindable('primary'),
    maxPopupHeight = $bindable(200),
    // Events
    opened,
    closed,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clear = $bindable((): Resolution => ({ success: true, data: null })),
    open = $bindable((): Resolution => ({ success: true, data: null })),
    close = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    items?: string | string[];
    value?: string | null;
    placeholder?: string;
    disabled?: boolean;
    invalid?: boolean;
    errorMessage?: string;
    helperText?: string;
    clearable?: boolean;
    searchable?: boolean;
    size?: string;
    variant?: string;
    maxPopupHeight?: number;
    opened?: (data?: unknown) => void;
    closed?: (data?: unknown) => void;
    focus?: () => Resolution;
    clear?: () => Resolution;
    open?: () => Resolution;
    close?: () => Resolution;
  } = $props();

  // --- Refs ---
  let rootEl: HTMLDivElement;
  let fieldEl: HTMLDivElement;
  let dropdownEl = $state<HTMLDivElement>();
  let searchInputEl = $state<HTMLInputElement>();
  let optionEls: HTMLDivElement[] = [];

  // --- IDs for ARIA ---
  const listboxId = `ic-select-listbox-${Math.random().toString(36).slice(2, 9)}`;

  // --- State ---
  let isOpen = $state(false);
  let isFocused = $state(false);
  let searchQuery = $state('');
  let focusedIndex = $state(-1);

  // --- Derived ---
  const itemList = $derived(
    Array.isArray(items) ? items : items ? [items] : []
  );

  const filteredItems = $derived(
    searchable && searchQuery
      ? itemList.filter((item) => item.toLowerCase().includes(searchQuery.toLowerCase()))
      : itemList
  );

  // string.empty from MATLAB arrives as [] or null; "" also means no selection
  const hasValue = $derived(
    value != null && value !== '' && !(Array.isArray(value) && value.length === 0)
  );
  const showClear = $derived(clearable && hasValue && !disabled);

  // --- Open / Close ---
  function openDropdown() {
    if (disabled || isOpen) return;
    isOpen = true;
    searchQuery = '';
    focusedIndex = -1;

    opened?.();

    requestAnimationFrame(() => {
      document.addEventListener('pointerdown', handleClickOutside);
      if (searchable && searchInputEl) {
        searchInputEl.focus();
      }
    });
  }

  function closeDropdown() {
    if (!isOpen) return;
    isOpen = false;
    searchQuery = '';
    focusedIndex = -1;
    closed?.();
    document.removeEventListener('pointerdown', handleClickOutside);
  }

  function toggleDropdown() {
    if (isOpen) closeDropdown();
    else openDropdown();
  }

  function handleClickOutside(e: PointerEvent) {
    const target = e.target as Node;
    if (rootEl && !rootEl.contains(target)) {
      closeDropdown();
    }
  }

  // --- Selection ---
  function selectItem(item: string) {
    value = item;
    closeDropdown();
    fieldEl?.focus();
  }

  function handleClear(e: Event) {
    e.stopPropagation();
    value = null;
    fieldEl?.focus();
  }

  // --- Keyboard ---
  function handleFieldKeydown(e: KeyboardEvent) {
    switch (e.key) {
      case 'Enter':
      case ' ':
        if (!isOpen) {
          e.preventDefault();
          openDropdown();
        } else if (focusedIndex >= 0 && focusedIndex < filteredItems.length) {
          e.preventDefault();
          selectItem(filteredItems[focusedIndex]);
        }
        break;
      case 'ArrowDown':
        e.preventDefault();
        if (!isOpen) {
          openDropdown();
        } else {
          moveFocus(1);
        }
        break;
      case 'ArrowUp':
        e.preventDefault();
        if (!isOpen) {
          openDropdown();
        } else {
          moveFocus(-1);
        }
        break;
      case 'Home':
        if (isOpen && filteredItems.length > 0) {
          e.preventDefault();
          focusedIndex = 0;
          scrollToFocused();
        }
        break;
      case 'End':
        if (isOpen && filteredItems.length > 0) {
          e.preventDefault();
          focusedIndex = filteredItems.length - 1;
          scrollToFocused();
        }
        break;
      case 'Escape':
        if (isOpen) {
          e.preventDefault();
          closeDropdown();
          fieldEl?.focus();
        }
        break;
      case 'Tab':
        if (isOpen) closeDropdown();
        break;
      default:
        // Type-ahead: jump to first matching option (when not searchable)
        if (!searchable && e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
          const char = e.key.toLowerCase();
          const idx = filteredItems.findIndex((item) =>
            item.toLowerCase().startsWith(char)
          );
          if (idx >= 0) {
            if (!isOpen) openDropdown();
            focusedIndex = idx;
            scrollToFocused();
          }
        }
    }
  }

  function handleSearchKeydown(e: KeyboardEvent) {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        moveFocus(1);
        break;
      case 'ArrowUp':
        e.preventDefault();
        moveFocus(-1);
        break;
      case 'Enter':
        if (focusedIndex >= 0 && focusedIndex < filteredItems.length) {
          e.preventDefault();
          selectItem(filteredItems[focusedIndex]);
        }
        break;
      case 'Escape':
        e.preventDefault();
        closeDropdown();
        fieldEl?.focus();
        break;
      case 'Home':
        if (filteredItems.length > 0) {
          e.preventDefault();
          focusedIndex = 0;
          scrollToFocused();
        }
        break;
      case 'End':
        if (filteredItems.length > 0) {
          e.preventDefault();
          focusedIndex = filteredItems.length - 1;
          scrollToFocused();
        }
        break;
    }
  }

  function moveFocus(delta: number) {
    if (filteredItems.length === 0) return;
    if (focusedIndex === -1) {
      focusedIndex = delta > 0 ? 0 : filteredItems.length - 1;
    } else {
      focusedIndex = Math.max(0, Math.min(filteredItems.length - 1, focusedIndex + delta));
    }
    scrollToFocused();
  }

  function scrollToFocused() {
    requestAnimationFrame(() => {
      const el = optionEls[focusedIndex];
      if (el) el.scrollIntoView({ block: 'nearest' });
    });
  }

  // Reset focused index when filtered items change
  $effect(() => {
    const _ = filteredItems;
    focusedIndex = -1;
  });

  // --- Methods ---
  $effect(() => {
    focus = (): Resolution => {
      fieldEl?.focus();
      return { success: true, data: null };
    };

    clear = (): Resolution => {
      value = null;
      return { success: true, data: null };
    };

    open = (): Resolution => {
      openDropdown();
      return { success: true, data: null };
    };

    close = (): Resolution => {
      closeDropdown();
      return { success: true, data: null };
    };
  });
</script>

<div
  bind:this={rootEl}
  class="ic-select"
  class:ic-select--sm={size === 'sm'}
  class:ic-select--md={size === 'md'}
  class:ic-select--lg={size === 'lg'}
  class:ic-select--disabled={disabled}
  class:ic-select--invalid={invalid}
  class:ic-select--open={isOpen}
>
  <!-- Trigger field -->
  <div
    bind:this={fieldEl}
    class="ic-select__field"
    class:ic-select__field--primary={variant === 'primary'}
    class:ic-select__field--secondary={variant === 'secondary'}
    class:ic-select__field--focused={isFocused}
    role="combobox"
    tabindex={disabled ? -1 : 0}
    aria-expanded={isOpen}
    aria-controls={listboxId}
    aria-haspopup="listbox"
    aria-invalid={invalid || undefined}
    onclick={toggleDropdown}
    onkeydown={handleFieldKeydown}
    onfocus={() => (isFocused = true)}
    onblur={() => (isFocused = false)}
  >
    <span
      class="ic-select__value"
      class:ic-select__value--placeholder={!hasValue}
    >
      {hasValue ? value : placeholder}
    </span>

    <span class="ic-select__actions">
      {#if showClear}
        <button
          class="ic-select__clear"
          tabindex={-1}
          aria-label="Clear selection"
          onclick={handleClear}
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M10.5 3.5L3.5 10.5M3.5 3.5L10.5 10.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      {/if}

      <span class="ic-select__arrow" class:ic-select__arrow--open={isOpen}>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M3 4.5L6 7.5L9 4.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </span>
    </span>
  </div>

  <!-- Helper / Error text -->
  {#if invalid && errorMessage}
    <span class="ic-select__error">{errorMessage}</span>
  {:else if helperText}
    <span class="ic-select__helper">{helperText}</span>
  {/if}

  <!-- Dropdown -->
  {#if isOpen}
    <div bind:this={dropdownEl} class="ic-select__dropdown">
      {#if searchable}
        <div class="ic-select__search-wrap">
          <input
            bind:this={searchInputEl}
            class="ic-select__search"
            type="text"
            placeholder="Search..."
            autocomplete="off"
            bind:value={searchQuery}
            onkeydown={handleSearchKeydown}
          />
        </div>
      {/if}

      <div
        class="ic-select__list"
        role="listbox"
        id={listboxId}
        style="max-height: {maxPopupHeight}px;"
      >
        {#each filteredItems as item, i (item)}
          <div
            bind:this={optionEls[i]}
            class="ic-select__option"
            class:ic-select__option--selected={item === value}
            class:ic-select__option--focused={i === focusedIndex}
            role="option"
            tabindex={-1}
            aria-selected={item === value}
            onclick={() => selectItem(item)}
            onkeydown={(e) => { if (e.key === 'Enter') selectItem(item); }}
            onpointerenter={() => (focusedIndex = i)}
          >
            <span class="ic-select__option-label">{item}</span>
            {#if item === value}
              <svg class="ic-select__check" width="14" height="14" viewBox="0 0 14 14" fill="none">
                <path d="M3 7L6 10L11 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            {/if}
          </div>
        {:else}
          <div class="ic-select__empty">No results</div>
        {/each}
      </div>
    </div>
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-select {
    display: inline-flex;
    flex-direction: column;
    gap: 0.25rem;
    font-family: inherit;
    width: 100%;
    position: relative;
  }

  /* ===== TRIGGER FIELD ===== */
  .ic-select__field {
    display: flex;
    align-items: center;
    border-radius: 3px;
    border: 1px solid var(--ic-border);
    background-color: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
    cursor: pointer;
    outline: none;
    user-select: none;
    gap: 0.25rem;
  }

  .ic-select__field--primary {
    border-color: var(--ic-border);
  }

  .ic-select__field--secondary {
    background-color: var(--ic-secondary);
    border-color: transparent;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  .ic-select__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-select__field--secondary.ic-select__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.18);
  }

  /* Invalid state */
  .ic-select--invalid .ic-select__field {
    border-color: var(--ic-destructive);
  }

  .ic-select--invalid .ic-select__field--focused {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  /* Disabled */
  .ic-select--disabled .ic-select__field {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: var(--ic-muted);
    pointer-events: none;
  }

  /* ===== VALUE DISPLAY ===== */
  .ic-select__value {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--ic-foreground);
    line-height: 1;
  }

  .ic-select__value--placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  /* ===== ACTIONS (clear + arrow) ===== */
  .ic-select__actions {
    display: flex;
    align-items: center;
    gap: 2px;
    flex-shrink: 0;
  }

  /* ===== CLEAR BUTTON ===== */
  .ic-select__clear {
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease, color 0.15s ease;
  }

  .ic-select__clear:hover {
    opacity: 1;
    color: var(--ic-foreground);
  }

  /* ===== CHEVRON ARROW ===== */
  .ic-select__arrow {
    display: flex;
    align-items: center;
    color: var(--ic-muted-foreground);
    transition: transform 0.15s ease;
  }

  .ic-select__arrow--open {
    transform: rotate(180deg);
  }

  /* ===== SIZES ===== */
  .ic-select--sm { font-size: 0.75rem; }
  .ic-select--md { font-size: 0.8125rem; }
  .ic-select--lg { font-size: 0.9375rem; }

  .ic-select--sm .ic-select__field { padding: 0.25rem 0.375rem; }
  .ic-select--md .ic-select__field { padding: 0.375rem 0.5rem; }
  .ic-select--lg .ic-select__field { padding: 0.5rem 0.625rem; }

  /* ===== DROPDOWN ===== */
  .ic-select__dropdown {
    position: absolute;
    z-index: 50;
    top: calc(100% + 4px);
    left: 0;
    width: 100%;
    display: flex;
    flex-direction: column;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    overflow: hidden;
  }

  /* ===== SEARCH ===== */
  .ic-select__search-wrap {
    padding: 6px 6px 4px;
    border-bottom: 1px solid var(--ic-border);
  }

  .ic-select__search {
    width: 100%;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-background);
    color: var(--ic-foreground);
    font-family: inherit;
    font-size: inherit;
    padding: 0.25rem 0.375rem;
    outline: none;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
    transition: border-color 0.15s ease;
    box-sizing: border-box;
  }

  .ic-select__search:focus {
    border-color: var(--ic-primary);
  }

  .ic-select__search::placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  /* ===== LIST ===== */
  .ic-select__list {
    overflow-y: auto;
    padding: 4px 0;
  }

  /* ===== OPTIONS ===== */
  .ic-select__option {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.375rem 0.5rem;
    cursor: pointer;
    color: var(--ic-foreground);
    transition: background-color 0.1s ease;
    user-select: none;
    gap: 0.5rem;
  }

  .ic-select__option--focused {
    background-color: var(--ic-secondary);
  }

  .ic-select__option--selected {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
  }

  .ic-select__option--selected.ic-select__option--focused {
    filter: brightness(0.9);
  }

  .ic-select__option-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }

  .ic-select__check {
    flex-shrink: 0;
  }

  /* ===== EMPTY STATE ===== */
  .ic-select__empty {
    padding: 0.5rem;
    text-align: center;
    color: var(--ic-muted-foreground);
    font-size: 0.8em;
    user-select: none;
  }

  /* ===== HELPER / ERROR TEXT ===== */
  .ic-select__helper,
  .ic-select__error {
    font-size: 0.7rem;
    line-height: 1.2;
    padding: 0 0.125rem;
  }

  .ic-select__helper {
    color: var(--ic-muted-foreground);
  }

  .ic-select__error {
    color: var(--ic-destructive);
  }
</style>
