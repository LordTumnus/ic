<script lang="ts">
  import type { EnumConfig } from '$lib/utils/table-utils';
  import { buildEnumColorMap } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<EnumConfig>,
    style = $bindable(''),
    editing = false,
    oncommitedit,
    oncanceledit,
  }: {
    value?: unknown;
    config?: Partial<EnumConfig>;
    style?: string;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
  } = $props();

  const items = $derived(config.items ?? []);
  const colorMap = $derived(buildEnumColorMap(config));

  const strVal = $derived(value != null && value !== '' ? String(value) : '');
  const isKnown = $derived(strVal !== '' && items.includes(strVal));
  const color = $derived(strVal ? (colorMap[strVal] ?? '') : '');

  /** Convert hex (#rrggbb) to an rgba string at the given alpha. */
  function hexToRgba(hex: string, alpha: number): string {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  const tagStyle = $derived.by((): string => {
    if (!strVal || !color) return '';
    return [
      `background:${hexToRgba(color, 0.10)}`,
      `color:${color}`,
      `border-color:${hexToRgba(color, 0.25)}`,
      `box-shadow:inset 0 1px 0 ${hexToRgba(color, 0.08)}`,
    ].join(';');
  });

  $effect(() => { style = ''; });

  // ── Edit mode (custom dropdown) ──────────────────
  let anchorEl = $state<HTMLElement>(null!);
  let listEl = $state<HTMLElement>(null!);
  let highlightIdx = $state(-1);
  let pos = $state<{ top: number; left: number; minWidth: number } | null>(null);

  // Position the dropdown when editing starts
  $effect(() => {
    if (editing && anchorEl) {
      const rect = anchorEl.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      const dropHeight = Math.min(items.length * 30 + 8, 200);  // estimate
      const flipUp = spaceBelow < dropHeight && rect.top > dropHeight;
      pos = {
        top: flipUp ? rect.top - dropHeight - 2 : rect.bottom + 2,
        left: rect.left,
        minWidth: Math.max(rect.width, 90),
      };
      highlightIdx = items.indexOf(strVal);
    } else {
      pos = null;
    }
  });

  // Click-outside listener
  $effect(() => {
    if (!editing) return;
    const handler = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (!target.closest('.ic-tbl-cell-enum__dropdown')) {
        oncanceledit?.();
      }
    };
    // Delay to avoid catching the double-click that opened editing
    const timer = setTimeout(() => {
      document.addEventListener('mousedown', handler, true);
    }, 0);
    return () => {
      clearTimeout(timer);
      document.removeEventListener('mousedown', handler, true);
    };
  });

  function handleItemClick(e: MouseEvent, item: string) {
    e.stopPropagation();
    e.preventDefault();
    oncommitedit?.(value, item);
  }

  function handleKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    switch (e.key) {
      case 'Escape':
        e.preventDefault();
        oncanceledit?.();
        break;
      case 'ArrowDown':
        e.preventDefault();
        highlightIdx = Math.min(highlightIdx + 1, items.length - 1);
        scrollToIdx();
        break;
      case 'ArrowUp':
        e.preventDefault();
        highlightIdx = Math.max(highlightIdx - 1, 0);
        scrollToIdx();
        break;
      case 'Enter':
        e.preventDefault();
        if (highlightIdx >= 0 && highlightIdx < items.length) {
          oncommitedit?.(value, items[highlightIdx]);
        } else {
          oncanceledit?.();
        }
        break;
    }
  }

  function scrollToIdx() {
    if (!listEl) return;
    const el = listEl.children[highlightIdx] as HTMLElement | undefined;
    el?.scrollIntoView({ block: 'nearest' });
  }

  function itemStyle(item: string): string {
    const c = colorMap[item];
    if (!c) return '';
    return `color:${c};`;
  }

  function itemDotStyle(item: string): string {
    const c = colorMap[item];
    return c ? `background:${c};` : 'background:var(--ic-muted-foreground);';
  }

  function autofocus(node: HTMLElement) {
    requestAnimationFrame(() => node.focus());
  }
</script>

{#if editing}
  <!-- Anchor to measure dropdown position from -->
  <div
    bind:this={anchorEl}
    class="ic-tbl-cell-enum__anchor"
    role="combobox"
    aria-expanded={pos != null}
    aria-controls="ic-enum-listbox"
    onkeydown={handleKeydown}
    use:autofocus
    tabindex={0}
  >
    {#if isKnown}
      <span class="ic-tbl-cell-enum" class:ic-tbl-cell-enum--muted={!color} style={tagStyle || null}>
        {strVal}
      </span>
    {:else if strVal}
      <span class="ic-tbl-cell-enum__text">{strVal}</span>
    {:else}
      <span class="ic-tbl-cell-enum__text ic-tbl-cell-enum__text--placeholder">Select…</span>
    {/if}
  </div>

  {#if pos}
    <div
      bind:this={listEl}
      id="ic-enum-listbox"
      class="ic-tbl-cell-enum__dropdown"
      role="listbox"
      tabindex={-1}
      style="top:{pos.top}px; left:{pos.left}px; min-width:{pos.minWidth}px;"
      onmousedown={(e) => e.preventDefault()}
    >
      {#each items as item, idx (item)}
        <div
          class="ic-tbl-cell-enum__option"
          class:ic-tbl-cell-enum__option--selected={item === strVal}
          class:ic-tbl-cell-enum__option--highlighted={idx === highlightIdx}
          role="option"
          aria-selected={item === strVal}
          tabindex={-1}
          style={itemStyle(item)}
          onclick={(e: MouseEvent) => handleItemClick(e, item)}
          onkeydown={handleKeydown}
          onpointerenter={() => { highlightIdx = idx; }}
        >
          <span class="ic-tbl-cell-enum__dot" style={itemDotStyle(item)}></span>
          <span class="ic-tbl-cell-enum__option-label">{item}</span>
          {#if item === strVal}
            <svg class="ic-tbl-cell-enum__check" viewBox="0 0 24 24" width="14" height="14">
              <path d="M20 6L9 17l-5-5" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
{:else if strVal}
  {#if isKnown}
    <span class="ic-tbl-cell-enum" class:ic-tbl-cell-enum--muted={!color} style={tagStyle || null}>
      {strVal}
    </span>
  {:else}
    <span class="ic-tbl-cell-enum__text">{strVal}</span>
  {/if}
{/if}

<style>
  .ic-tbl-cell-enum {
    display: inline-block;
    padding: 1px 6px;
    border: 1px solid transparent;
    border-radius: 2px;
    font-weight: 500;
    line-height: 1.4;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 100%;
  }
  .ic-tbl-cell-enum--muted {
    background: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    border-color: var(--ic-border);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }
  .ic-tbl-cell-enum__text {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ic-tbl-cell-enum__text--placeholder {
    color: var(--ic-muted-foreground);
    font-style: italic;
  }

  /* ── Edit anchor ──────────────────────────── */
  .ic-tbl-cell-enum__anchor {
    display: flex;
    align-items: center;
    width: 100%;
    height: 100%;
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
    border-radius: 2px;
    cursor: pointer;
  }
  .ic-tbl-cell-enum__anchor:focus {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
  }

  /* ── Dropdown panel ───────────────────────── */
  .ic-tbl-cell-enum__dropdown {
    position: fixed;
    z-index: 9999;
    max-height: 200px;
    overflow-y: auto;
    padding: 3px 0;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }

  /* ── Option row ───────────────────────────── */
  .ic-tbl-cell-enum__option {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
    cursor: pointer;
    font-size: 0.8rem;
    font-weight: 500;
    line-height: 1.4;
    white-space: nowrap;
    transition: background-color 0.06s ease;
  }
  .ic-tbl-cell-enum__option--highlighted {
    background: var(--ic-secondary);
  }
  .ic-tbl-cell-enum__option--selected {
    font-weight: 600;
  }

  /* Color dot indicator */
  .ic-tbl-cell-enum__dot {
    flex-shrink: 0;
    width: 8px;
    height: 8px;
    border-radius: 1px;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-tbl-cell-enum__option-label {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Checkmark for selected item */
  .ic-tbl-cell-enum__check {
    flex-shrink: 0;
    opacity: 0.7;
  }
</style>
