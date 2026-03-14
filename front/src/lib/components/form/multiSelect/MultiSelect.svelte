<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution } from '$lib/types';
  import Tag from '$lib/components/shared/Tag.svelte';

  let {
    items = $bindable(['Option 1', 'Option 2', 'Option 3']),
    value = $bindable<string[] | string | null>(null),
    placeholder = $bindable('Select...'),
    disabled = $bindable(false),
    clearable = $bindable(false),
    size = $bindable('md'),
    variant = $bindable('primary'),
    maxPopupHeight = $bindable(200),
    maxSelectedItems = $bindable<number | null>(null),
    // Events
    valueChanged,
    opened,
    closed,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clear = $bindable((): Resolution => ({ success: true, data: null })),
    open = $bindable((): Resolution => ({ success: true, data: null })),
    close = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    items?: string | string[];
    value?: string[] | string | null;
    placeholder?: string;
    disabled?: boolean;
    clearable?: boolean;
    size?: string;
    variant?: string;
    maxPopupHeight?: number;
    maxSelectedItems?: number | null;
    valueChanged?: (data?: unknown) => void;
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
  let searchInputEl: HTMLInputElement;
  let optionEls: HTMLDivElement[] = [];

  // --- IDs for ARIA ---
  const listboxId = `ic-ms-listbox-${Math.random().toString(36).slice(2, 9)}`;

  // --- State ---
  let isOpen = $state(false);
  let isFocused = $state(false);
  let searchQuery = $state('');
  let focusedOptionIndex = $state(-1);
  let focusedTagIndex = $state(-1);
  let removingIndex = $state(-1);

  // --- Derived ---
  const itemList = $derived(
    Array.isArray(items) ? items : items ? [items] : []
  );

  const valueList = $derived.by((): string[] => {
    if (value == null) return [];
    if (Array.isArray(value)) return value.filter((v) => v !== '' && v != null);
    if (value === '') return [];
    return [value];
  });

  const hasValue = $derived(valueList.length > 0);
  const showClear = $derived(clearable && hasValue && !disabled);
  const atMaxSelections = $derived(maxSelectedItems != null && valueList.length >= maxSelectedItems);

  const filteredItems = $derived.by(() => {
    let filtered = itemList;
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      filtered = filtered.filter((item) => item.toLowerCase().includes(q));
    }
    return filtered;
  });

  function isSelected(item: string): boolean {
    return valueList.includes(item);
  }

  // --- Open / Close ---
  function openDropdown() {
    if (disabled || isOpen) return;
    isOpen = true;
    searchQuery = '';
    focusedOptionIndex = -1;
    opened?.();
    requestAnimationFrame(() => {
      document.addEventListener('pointerdown', handleClickOutside);
      searchInputEl?.focus();
    });
  }

  function closeDropdown() {
    if (!isOpen) return;
    isOpen = false;
    searchQuery = '';
    focusedOptionIndex = -1;
    closed?.();
    document.removeEventListener('pointerdown', handleClickOutside);
  }

  function handleClickOutside(e: PointerEvent) {
    const target = e.target as Node;
    if (rootEl && !rootEl.contains(target)) {
      closeDropdown();
    }
  }

  // --- Selection ---
  function toggleItem(item: string) {
    let newValue: string[];

    if (isSelected(item)) {
      newValue = valueList.filter((v) => v !== item);
    } else {
      if (atMaxSelections) return;
      newValue = [...valueList, item];
    }

    value = newValue.length > 0 ? newValue : null;
    valueChanged?.({ value });

    // Keep dropdown open, refocus search
    requestAnimationFrame(() => searchInputEl?.focus());
  }

  function removeTag(item: string) {
    const newValue = valueList.filter((v) => v !== item);
    value = newValue.length > 0 ? newValue : null;
  }

  function handleTagRemoved(item: string) {
    removeTag(item);
    valueChanged?.({ value });
    if (removingIndex >= 0) {
      removingIndex = -1;
      if (valueList.length === 0) {
        focusedTagIndex = -1;
        searchInputEl?.focus();
      } else if (focusedTagIndex >= valueList.length) {
        focusedTagIndex = valueList.length - 1;
      }
    }
  }

  function handleClearAll(e: Event) {
    e.stopPropagation();
    value = null;
    valueChanged?.({ value: null });
    searchQuery = '';
    searchInputEl?.focus();
  }

  // --- Tag reordering ---
  function swapTags(fromIdx: number, toIdx: number) {
    if (toIdx < 0 || toIdx >= valueList.length) return;
    const arr = valueList.slice();
    const temp = arr[fromIdx];
    arr[fromIdx] = arr[toIdx];
    arr[toIdx] = temp;
    value = arr;
    focusedTagIndex = toIdx;
  }

  // --- Keyboard: search input ---
  function handleSearchKeydown(e: KeyboardEvent) {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        if (!isOpen) {
          openDropdown();
        } else {
          moveOptionFocus(1);
        }
        break;
      case 'ArrowUp':
        e.preventDefault();
        if (!isOpen) {
          openDropdown();
        } else {
          moveOptionFocus(-1);
        }
        break;
      case 'Enter':
        if (isOpen && focusedOptionIndex >= 0 && focusedOptionIndex < filteredItems.length) {
          e.preventDefault();
          toggleItem(filteredItems[focusedOptionIndex]);
        }
        break;
      case 'Escape':
        if (isOpen) {
          e.preventDefault();
          closeDropdown();
        }
        break;
      case 'Backspace':
        if (searchQuery === '' && valueList.length > 0) {
          e.preventDefault();
          focusedTagIndex = valueList.length - 1;
        }
        break;
      case 'ArrowLeft':
        if (searchInputEl?.selectionStart === 0 && valueList.length > 0) {
          e.preventDefault();
          focusedTagIndex = valueList.length - 1;
        }
        break;
      case 'Home':
        if (isOpen && filteredItems.length > 0) {
          e.preventDefault();
          focusedOptionIndex = 0;
          scrollToFocusedOption();
        }
        break;
      case 'End':
        if (isOpen && filteredItems.length > 0) {
          e.preventDefault();
          focusedOptionIndex = filteredItems.length - 1;
          scrollToFocusedOption();
        }
        break;
      case 'Tab':
        if (isOpen) closeDropdown();
        break;
    }
  }

  // --- Keyboard: tag navigation ---
  function handleTagKeydown(e: KeyboardEvent) {
    if (focusedTagIndex < 0) return;

    switch (e.key) {
      case 'ArrowLeft':
        e.preventDefault();
        if (e.shiftKey) {
          swapTags(focusedTagIndex, focusedTagIndex - 1);
        } else if (focusedTagIndex > 0) {
          focusedTagIndex = focusedTagIndex - 1;
        }
        break;
      case 'ArrowRight':
        e.preventDefault();
        if (e.shiftKey) {
          swapTags(focusedTagIndex, focusedTagIndex + 1);
        } else if (focusedTagIndex < valueList.length - 1) {
          focusedTagIndex = focusedTagIndex + 1;
        } else {
          // Past last tag → back to search input
          focusedTagIndex = -1;
          searchInputEl?.focus();
        }
        break;
      case 'Delete':
      case 'Backspace': {
        e.preventDefault();
        if (removingIndex >= 0) break;
        removingIndex = focusedTagIndex;
        break;
      }
      case 'Escape':
        e.preventDefault();
        focusedTagIndex = -1;
        searchInputEl?.focus();
        break;
      default:
        // Printable character → return to search input and type
        if (e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
          focusedTagIndex = -1;
          searchInputEl?.focus();
          // Don't prevent default — let the char be typed
        }
    }
  }

  // --- Dropdown focus ---
  function moveOptionFocus(delta: number) {
    if (filteredItems.length === 0) return;
    if (focusedOptionIndex === -1) {
      focusedOptionIndex = delta > 0 ? 0 : filteredItems.length - 1;
    } else {
      focusedOptionIndex = Math.max(0, Math.min(filteredItems.length - 1, focusedOptionIndex + delta));
    }
    scrollToFocusedOption();
  }

  function scrollToFocusedOption() {
    requestAnimationFrame(() => {
      const el = optionEls[focusedOptionIndex];
      if (el) el.scrollIntoView({ block: 'nearest' });
    });
  }

  // Reset focused option when filtered items change
  $effect(() => {
    const _ = filteredItems;
    focusedOptionIndex = -1;
  });

  // --- Field click ---
  function handleFieldClick() {
    if (disabled) return;
    if (!isOpen) {
      openDropdown();
    }
    focusedTagIndex = -1;
    searchInputEl?.focus();
  }

  // --- Methods ---
  onMount(() => {
    focus = (): Resolution => {
      searchInputEl?.focus();
      return { success: true, data: null };
    };

    clear = (): Resolution => {
      value = null;
      valueChanged?.({ value: null });
      searchQuery = '';
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

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={rootEl}
  class="ic-ms"
  class:ic-ms--sm={size === 'sm'}
  class:ic-ms--md={size === 'md'}
  class:ic-ms--lg={size === 'lg'}
  class:ic-ms--disabled={disabled}
  class:ic-ms--open={isOpen}
  onkeydown={focusedTagIndex >= 0 ? handleTagKeydown : undefined}
>
  <!-- Field wrapper -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    bind:this={fieldEl}
    class="ic-ms__field"
    class:ic-ms__field--primary={variant === 'primary'}
    class:ic-ms__field--secondary={variant === 'secondary'}
    class:ic-ms__field--focused={isFocused}
    role="combobox"
    tabindex={disabled ? -1 : 0}
    aria-expanded={isOpen}
    aria-controls={listboxId}
    aria-haspopup="listbox"
    onclick={handleFieldClick}
  >
    <div class="ic-ms__tags-input">
      <!-- Selected tags -->
      {#each valueList as item, i (i)}
        <Tag
          label={item}
          {size}
          {disabled}
          active={focusedTagIndex === i}
          removing={removingIndex === i}
          onremove={() => handleTagRemoved(item)}
        />
      {/each}

      <!-- Inline search input -->
      <input
        bind:this={searchInputEl}
        class="ic-ms__search"
        type="text"
        placeholder={hasValue ? '' : placeholder}
        autocomplete="off"
        {disabled}
        bind:value={searchQuery}
        oninput={() => { if (searchQuery && !isOpen) openDropdown(); }}
        onkeydown={handleSearchKeydown}
        onfocus={() => { isFocused = true; }}
        onblur={() => { isFocused = false; }}
      />
    </div>

    <!-- Actions -->
    <span class="ic-ms__actions">
      {#if showClear}
        <button
          class="ic-ms__clear"
          tabindex={-1}
          aria-label="Clear all selections"
          onclick={handleClearAll}
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M10.5 3.5L3.5 10.5M3.5 3.5L10.5 10.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      {/if}

      <span class="ic-ms__arrow" class:ic-ms__arrow--open={isOpen}>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M3 4.5L6 7.5L9 4.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </span>
    </span>
  </div>

  <!-- Dropdown -->
  {#if isOpen}
    <div class="ic-ms__dropdown">
      <div
        class="ic-ms__list"
        role="listbox"
        id={listboxId}
        aria-multiselectable="true"
        style="max-height: {maxPopupHeight}px;"
      >
        {#each filteredItems as item, i (item)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <div
            bind:this={optionEls[i]}
            class="ic-ms__option"
            class:ic-ms__option--selected={isSelected(item)}
            class:ic-ms__option--focused={i === focusedOptionIndex}
            class:ic-ms__option--disabled={atMaxSelections && !isSelected(item)}
            role="option"
            tabindex={-1}
            aria-selected={isSelected(item)}
            onclick={() => toggleItem(item)}
            onpointerenter={() => { focusedOptionIndex = i; }}
          >
            <!-- Checkbox indicator -->
            <span class="ic-ms__checkbox" class:ic-ms__checkbox--checked={isSelected(item)}>
              {#if isSelected(item)}
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                  <path d="M2 5L4 7L8 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              {/if}
            </span>

            <span class="ic-ms__option-label">{item}</span>
          </div>
        {:else}
          <div class="ic-ms__empty">No results</div>
        {/each}
      </div>
    </div>
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-ms {
    display: inline-flex;
    flex-direction: column;
    gap: 0.25rem;
    font-family: inherit;
    width: 100%;
    position: relative;
  }

  /* ===== FIELD WRAPPER ===== */
  .ic-ms__field {
    display: flex;
    align-items: center;
    border-radius: 3px;
    border: 1px solid var(--ic-border);
    background-color: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
    cursor: text;
    outline: none;
    gap: 0.25rem;
  }

  .ic-ms__field--primary {
    border-color: var(--ic-border);
  }

  .ic-ms__field--secondary {
    background-color: var(--ic-secondary);
    border-color: transparent;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  .ic-ms__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-ms__field--secondary.ic-ms__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.18);
  }

  .ic-ms--disabled .ic-ms__field {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: var(--ic-muted);
    pointer-events: none;
  }

  /* ===== TAGS + INPUT AREA ===== */
  .ic-ms__tags-input {
    display: flex;
    align-items: center;
    overflow-x: auto;
    overflow-y: hidden;
    gap: 3px;
    flex: 1;
    min-width: 0;
  }
  .ic-ms__tags-input::-webkit-scrollbar {
    height: 3px;
  }
  .ic-ms__tags-input::-webkit-scrollbar-track {
    background: transparent;
  }
  .ic-ms__tags-input::-webkit-scrollbar-thumb {
    background: var(--ic-border);
    border-radius: 3px;
  }

  /* ===== INLINE SEARCH ===== */
  .ic-ms__search {
    flex: 1;
    min-width: 60px;
    border: none;
    outline: none;
    background: transparent;
    color: var(--ic-foreground);
    font-family: inherit;
    font-size: inherit;
    line-height: 1;
    padding: 0;
  }

  .ic-ms__search::placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  .ic-ms__search:disabled {
    cursor: not-allowed;
  }

  /* ===== ACTIONS ===== */
  .ic-ms__actions {
    display: flex;
    align-items: center;
    gap: 2px;
    flex-shrink: 0;
    align-self: flex-start;
  }

  /* ===== CLEAR BUTTON ===== */
  .ic-ms__clear {
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

  .ic-ms__clear:hover {
    opacity: 1;
    color: var(--ic-foreground);
  }

  /* ===== CHEVRON ===== */
  .ic-ms__arrow {
    display: flex;
    align-items: center;
    color: var(--ic-muted-foreground);
    transition: transform 0.15s ease;
  }

  .ic-ms__arrow--open {
    transform: rotate(180deg);
  }

  /* ===== SIZES ===== */
  .ic-ms--sm { font-size: 0.75rem; }
  .ic-ms--md { font-size: 0.8125rem; }
  .ic-ms--lg { font-size: 0.9375rem; }

  .ic-ms--sm .ic-ms__field { padding: 0.25rem 0.375rem; min-height: 1.75rem; }
  .ic-ms--md .ic-ms__field { padding: 0.375rem 0.5rem; min-height: 2.25rem; }
  .ic-ms--lg .ic-ms__field { padding: 0.5rem 0.625rem; min-height: 2.75rem; }

  .ic-ms--sm .ic-ms__tags-input { min-height: 18px; }
  .ic-ms--md .ic-ms__tags-input { min-height: 22px; }
  .ic-ms--lg .ic-ms__tags-input { min-height: 24px; }

  .ic-ms--sm .ic-ms__actions { padding-top: 0.2rem; }
  .ic-ms--md .ic-ms__actions { padding-top: 0.3rem; }
  .ic-ms--lg .ic-ms__actions { padding-top: 0.4rem; }

  /* ===== DROPDOWN ===== */
  .ic-ms__dropdown {
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

  /* ===== LIST ===== */
  .ic-ms__list {
    overflow-y: auto;
    padding: 4px 0;
  }

  /* ===== OPTIONS ===== */
  .ic-ms__option {
    display: flex;
    align-items: center;
    padding: 0.375rem 0.5rem;
    cursor: pointer;
    color: var(--ic-foreground);
    transition: background-color 0.1s ease;
    user-select: none;
    gap: 0.5rem;
  }

  .ic-ms__option--focused {
    background-color: var(--ic-secondary);
  }

  .ic-ms__option--selected {
    font-weight: 500;
  }

  .ic-ms__option--disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .ic-ms__option-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
    flex: 1;
  }

  /* ===== CHECKBOX INDICATOR ===== */
  .ic-ms__checkbox {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
    flex-shrink: 0;
    transition: background-color 0.12s ease, border-color 0.12s ease;
  }

  .ic-ms__checkbox--checked {
    background-color: var(--ic-primary);
    border-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
  }

  /* ===== EMPTY STATE ===== */
  .ic-ms__empty {
    padding: 0.5rem;
    text-align: center;
    color: var(--ic-muted-foreground);
    font-size: 0.8em;
    user-select: none;
  }
</style>
