<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution } from '$lib/types';
  import Tag from '$lib/components/shared/Tag.svelte';

  let {
    value = $bindable<string[] | string | null>(null),
    placeholder = $bindable('Search...'),
    disabled = $bindable(false),
    clearable = $bindable(false),
    size = $bindable('md'),
    variant = $bindable('primary'),
    separator = $bindable(','),
    iconTriggers = $bindable<Record<string, string> | null>(null),
    // Events
    valueChanged,
    submitted,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clear = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: string[] | string | null;
    placeholder?: string;
    disabled?: boolean;
    clearable?: boolean;
    size?: string;
    variant?: string;
    separator?: string;
    iconTriggers?: Record<string, string> | null;
    valueChanged?: (data?: unknown) => void;
    submitted?: (data?: unknown) => void;
    focus?: () => Resolution;
    clear?: () => Resolution;
  } = $props();

  // --- Refs ---
  let inputEl: HTMLInputElement;

  // --- State ---
  let isFocused = $state(false);
  let focusedTagIndex = $state(-1);
  let inputText = $state('');
  let removingIndex = $state(-1);

  // --- Derived ---
  const valueList = $derived.by((): string[] => {
    if (value == null) return [];
    if (Array.isArray(value)) return value.filter((v) => v !== '' && v != null);
    if (value === '') return [];
    return [value];
  });

  const hasValue = $derived(valueList.length > 0);
  const showClear = $derived(clearable && (hasValue || inputText.length > 0) && !disabled);

  // --- Icon trigger matching ---
  // Sort triggers by length descending so longest prefix matches first
  const sortedTriggers = $derived.by(() => {
    if (!iconTriggers) return [];
    return Object.entries(iconTriggers)
      .map(([trigger, icon]) => ({ trigger, icon }))
      .sort((a, b) => b.trigger.length - a.trigger.length);
  });

  function matchTrigger(text: string): { icon: string; label: string } {
    for (const { trigger, icon } of sortedTriggers) {
      if (trigger && text.startsWith(trigger)) {
        return { icon, label: text.slice(trigger.length) };
      }
    }
    return { icon: '', label: text };
  }

  /**
   * Resolve the icon for a tag that's already in the value array.
   * We re-check icon triggers against the stored tag text.
   * Tags are stored WITH their trigger prefix so we can reconstruct the icon.
   */
  function iconForTag(tag: string): string {
    return matchTrigger(tag).icon;
  }

  function labelForTag(tag: string): string {
    return matchTrigger(tag).label;
  }

  // --- Tag creation from input ---
  function commitTag(rawText: string) {
    const text = rawText.trim();
    if (!text) return;
    // Store the full text (with trigger prefix) so icon can be re-derived
    const newValue = [...valueList, text];
    value = newValue;
    valueChanged?.({ value });
    inputText = '';
  }

  // --- Tag management ---
  function removeTag(tag: string) {
    const newValue = valueList.filter((t) => t !== tag);
    value = newValue.length > 0 ? newValue : null;
  }

  function handleTagRemoved(tag: string) {
    removeTag(tag);
    valueChanged?.({ value });
    if (removingIndex >= 0) {
      removingIndex = -1;
      if (valueList.length === 0) {
        focusedTagIndex = -1;
        inputEl?.focus();
      } else if (focusedTagIndex >= valueList.length) {
        focusedTagIndex = valueList.length - 1;
      }
    }
  }

  function swapTags(fromIdx: number, toIdx: number) {
    if (toIdx < 0 || toIdx >= valueList.length) return;
    const arr = valueList.slice();
    const temp = arr[fromIdx];
    arr[fromIdx] = arr[toIdx];
    arr[toIdx] = temp;
    value = arr;
    focusedTagIndex = toIdx;
  }

  function handleClearAll(e: Event) {
    e.stopPropagation();
    value = null;
    valueChanged?.({ value: null });
    inputText = '';
    inputEl?.focus();
  }

  // --- Input handlers ---
  function handleInput(e: Event) {
    const target = e.currentTarget as HTMLInputElement;
    const raw = target.value;

    // Check if separator was typed
    if (separator && raw.includes(separator)) {
      const parts = raw.split(separator);
      // Batch: collect all new tags, apply in one update
      const newTags = parts.slice(0, -1).map((p) => p.trim()).filter(Boolean);
      if (newTags.length > 0) {
        value = [...valueList, ...newTags];
        valueChanged?.({ value });
      }
      inputText = parts[parts.length - 1];
    } else {
      inputText = raw;
    }
  }

  function handleInputKeydown(e: KeyboardEvent) {
    switch (e.key) {
      case 'Enter':
        // Commit current text as tag, then fire submitted
        if (inputText.trim()) {
          commitTag(inputText);
        }
        submitted?.({ value: valueList });
        break;
      case 'Backspace':
        if (inputText === '' && valueList.length > 0) {
          e.preventDefault();
          focusedTagIndex = valueList.length - 1;
        }
        break;
      case 'ArrowLeft':
        if (inputEl?.selectionStart === 0 && valueList.length > 0) {
          e.preventDefault();
          focusedTagIndex = valueList.length - 1;
        }
        break;
      case 'Escape':
        focusedTagIndex = -1;
        inputEl?.blur();
        break;
    }
  }

  // --- Tag keyboard navigation ---
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
          focusedTagIndex = -1;
          inputEl?.focus();
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
        inputEl?.focus();
        break;
      default:
        if (e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
          focusedTagIndex = -1;
          inputEl?.focus();
        }
    }
  }

  // --- Field click ---
  function handleFieldClick() {
    if (disabled) return;
    focusedTagIndex = -1;
    inputEl?.focus();
  }

  // --- Methods ---
  onMount(() => {
    focus = (): Resolution => {
      inputEl?.focus();
      return { success: true, data: null };
    };

    clear = (): Resolution => {
      value = null;
      valueChanged?.({ value: null });
      inputText = '';
      return { success: true, data: null };
    };
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-sb"
  class:ic-sb--sm={size === 'sm'}
  class:ic-sb--md={size === 'md'}
  class:ic-sb--lg={size === 'lg'}
  class:ic-sb--disabled={disabled}
  onkeydown={focusedTagIndex >= 0 ? handleTagKeydown : undefined}
>
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    class="ic-sb__field"
    class:ic-sb__field--primary={variant === 'primary'}
    class:ic-sb__field--secondary={variant === 'secondary'}
    class:ic-sb__field--focused={isFocused}
    onclick={handleFieldClick}
  >
    <!-- Search icon -->
    <span class="ic-sb__search-icon">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="11" cy="11" r="8"/>
        <path d="M21 21l-4.35-4.35"/>
      </svg>
    </span>

    <div class="ic-sb__tags-input">
      <!-- Tags -->
      {#each valueList as tag, i (i)}
        <Tag
          label={labelForTag(tag)}
          icon={iconForTag(tag)}
          {size}
          {disabled}
          active={focusedTagIndex === i}
          removing={removingIndex === i}
          onremove={() => handleTagRemoved(tag)}
        />
      {/each}

      <!-- Text input -->
      <input
        bind:this={inputEl}
        class="ic-sb__input"
        type="text"
        placeholder={hasValue ? '' : placeholder}
        autocomplete="off"
        {disabled}
        value={inputText}
        oninput={handleInput}
        onkeydown={handleInputKeydown}
        onfocus={() => { isFocused = true; }}
        onblur={() => { isFocused = false; }}
      />
    </div>

    <!-- Clear button -->
    {#if showClear}
      <button
        class="ic-sb__clear"
        tabindex={-1}
        aria-label="Clear search"
        onclick={handleClearAll}
      >
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M10.5 3.5L3.5 10.5M3.5 3.5L10.5 10.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
    {/if}
  </div>
</div>

<style>
  /* ===== ROOT ===== */
  .ic-sb {
    display: inline-flex;
    flex-direction: column;
    gap: 0.25rem;
    font-family: inherit;
    width: 100%;
  }

  /* ===== FIELD WRAPPER ===== */
  .ic-sb__field {
    display: flex;
    align-items: center;
    border-radius: 3px;
    border: 1px solid var(--ic-border);
    background-color: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
    cursor: text;
    outline: none;
    gap: 0.375rem;
  }

  .ic-sb__field--primary {
    border-color: var(--ic-border);
  }

  .ic-sb__field--secondary {
    background-color: var(--ic-secondary);
    border-color: transparent;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  .ic-sb__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-sb__field--secondary.ic-sb__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.18);
  }

  .ic-sb--disabled .ic-sb__field {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: var(--ic-muted);
    pointer-events: none;
  }

  /* ===== SEARCH ICON ===== */
  .ic-sb__search-icon {
    display: flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  /* ===== TAGS + INPUT AREA ===== */
  .ic-sb__tags-input {
    display: flex;
    align-items: center;
    gap: 3px;
    flex: 1;
    min-width: 0;
    overflow-x: auto;
    overflow-y: hidden;
  }
  .ic-sb__tags-input::-webkit-scrollbar {
    height: 3px;
  }
  .ic-sb__tags-input::-webkit-scrollbar-track {
    background: transparent;
  }
  .ic-sb__tags-input::-webkit-scrollbar-thumb {
    background: var(--ic-border);
    border-radius: 3px;
  }

  /* ===== TEXT INPUT ===== */
  .ic-sb__input {
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

  .ic-sb__input::placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  .ic-sb__input:disabled {
    cursor: not-allowed;
  }

  /* ===== CLEAR BUTTON ===== */
  .ic-sb__clear {
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease, color 0.15s ease;
  }

  .ic-sb__clear:hover {
    opacity: 1;
    color: var(--ic-foreground);
  }

  /* ===== SIZES ===== */
  .ic-sb--sm { font-size: 0.75rem; }
  .ic-sb--md { font-size: 0.8125rem; }
  .ic-sb--lg { font-size: 0.9375rem; }

  .ic-sb--sm .ic-sb__field { padding: 0.25rem 0.375rem; min-height: 1.75rem; }
  .ic-sb--md .ic-sb__field { padding: 0.375rem 0.5rem; min-height: 2.25rem; }
  .ic-sb--lg .ic-sb__field { padding: 0.5rem 0.625rem; min-height: 2.75rem; }

  .ic-sb--sm .ic-sb__tags-input { min-height: 18px; }
  .ic-sb--md .ic-sb__tags-input { min-height: 22px; }
  .ic-sb--lg .ic-sb__tags-input { min-height: 24px; }

  .ic-sb--sm .ic-sb__search-icon svg { width: 12px; height: 12px; }
  .ic-sb--md .ic-sb__search-icon svg { width: 14px; height: 14px; }
  .ic-sb--lg .ic-sb__search-icon svg { width: 16px; height: 16px; }
</style>
