<script lang="ts">
  import type { ContextMenuEntry, ContextMenuFolder } from '$lib/utils/context-menu-types';
  import Icon from '$lib/components/display/icon/Icon.svelte';
  import ContextMenuPanel from './ContextMenuPanel.svelte';
  import SaturationValuePad from '$lib/components/form/colorPicker/SaturationValuePad.svelte';
  import HueSlider from '$lib/components/form/colorPicker/HueSlider.svelte';
  import { parseColor, hslToHsv, hsvToHsl, formatColor } from '$lib/utils/color';

  let {
    entries,
    x,
    y,
    onaction,
    onclose,
  }: {
    entries: ContextMenuEntry[];
    x: number;
    y: number;
    onaction: (key: string) => void;
    onclose: () => void;
  } = $props();

  let panelEl: HTMLDivElement;

  // Viewport-clamp position — derived from props (reactive to x/y changes)
  let panelWidth = $state(0);
  let panelHeight = $state(0);

  $effect(() => {
    if (panelEl) {
      panelWidth = panelEl.offsetWidth;
      panelHeight = panelEl.offsetHeight;
    }
  });

  const adjustedX = $derived.by(() => {
    const vw = typeof window !== 'undefined' ? window.innerWidth : 9999;
    return (x + panelWidth > vw) ? Math.max(0, vw - panelWidth - 4) : x;
  });

  const adjustedY = $derived.by(() => {
    const vh = typeof window !== 'undefined' ? window.innerHeight : 9999;
    return (y + panelHeight > vh) ? Math.max(0, vh - panelHeight - 4) : y;
  });

  // Submenu state
  let openFolder = $state<{ folder: ContextMenuFolder; x: number; y: number } | null>(null);
  let hoverTimer: ReturnType<typeof setTimeout> | null = null;

  function handleFolderEnter(e: PointerEvent, folder: ContextMenuFolder) {
    if (hoverTimer) clearTimeout(hoverTimer);
    const target = e.currentTarget as HTMLElement;
    hoverTimer = setTimeout(() => {
      const rect = target.getBoundingClientRect();
      // Open to the right; ContextMenuPanel will viewport-clamp if overflow
      openFolder = {
        folder,
        x: rect.right,
        y: rect.top,
      };
    }, 150);
  }

  function handleFolderLeave() {
    if (hoverTimer) {
      clearTimeout(hoverTimer);
      hoverTimer = null;
    }
  }

  function handleItemClick(key: string) {
    onaction(key);
  }

  // -- Color picker state ---------------------------------------------------

  let openColorKey = $state<string | null>(null);
  let colorPos = $state<{ x: number; y: number }>({ x: 0, y: 0 });
  let colorHue = $state(0);
  let colorSatV = $state(100);
  let colorVal = $state(100);

  function handleColorClick(e: MouseEvent, key: string, currentValue: string) {
    if (openColorKey === key) {
      openColorKey = null;
      return;
    }
    const target = (e.currentTarget as HTMLElement);
    const rect = target.getBoundingClientRect();
    colorPos = { x: rect.right, y: rect.top };
    const parsed = parseColor(currentValue || '#3b82f6');
    const hsv = hslToHsv(parsed.h, parsed.s, parsed.l);
    colorHue = hsv.h;
    colorSatV = hsv.s;
    colorVal = hsv.v;
    openColorKey = key;
  }

  // Live preview color derived from picker state
  const liveColor = $derived.by(() => {
    const hsl = hsvToHsl(colorHue, colorSatV, colorVal);
    return `hsl(${hsl.h}, ${hsl.s}%, ${hsl.l}%)`;
  });

  function emitColor(key: string) {
    const hsl = hsvToHsl(colorHue, colorSatV, colorVal);
    const hex = formatColor(hsl.h, hsl.s, hsl.l, 1, 'hex', false);
    onaction(`${key}:${hex}`);
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events a11y_interactive_supports_focus -->
<div
  bind:this={panelEl}
  class="ic-ctx__panel"
  style:left="{adjustedX}px"
  style:top="{adjustedY}px"
  onclick={(e: MouseEvent) => e.stopPropagation()}
  onpointerdown={(e: PointerEvent) => e.stopPropagation()}
  role="menu"
  tabindex={-1}
>
  {#each entries as entry, idx (idx)}
    {#if entry.type === 'separator'}
      <div class="ic-ctx__separator"></div>
    {:else if entry.type === 'item'}
      <button
        class="ic-ctx__item"
        class:ic-ctx__item--disabled={entry.disabled}
        onclick={() => handleItemClick(entry.key)}
        disabled={entry.disabled}
      >
        <span class="ic-ctx__icon">
          {#if entry.icon}
            <Icon source={entry.icon} size={14} />
          {/if}
        </span>
        <span class="ic-ctx__label">{entry.label || entry.key}</span>
        {#if entry.shortcut}
          <span class="ic-ctx__shortcut">{entry.shortcut}</span>
        {/if}
      </button>
    {:else if entry.type === 'folder'}
      <button
        class="ic-ctx__item ic-ctx__item--folder"
        class:ic-ctx__item--disabled={entry.disabled}
        onpointerenter={(e: PointerEvent) => handleFolderEnter(e, entry)}
        onpointerleave={handleFolderLeave}
        disabled={entry.disabled}
      >
        <span class="ic-ctx__icon">
          {#if entry.icon}
            <Icon source={entry.icon} size={14} />
          {/if}
        </span>
        <span class="ic-ctx__label">{entry.label || ''}</span>
        <span class="ic-ctx__chevron">
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M3.5 2L6.5 5L3.5 8" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </span>
      </button>
      {#if openFolder && openFolder.folder === entry && entry.children?.length}
        <ContextMenuPanel
          entries={entry.children}
          x={openFolder.x}
          y={openFolder.y}
          {onaction}
          {onclose}
        />
      {/if}
    {:else if entry.type === 'color'}
      <button
        class="ic-ctx__item"
        onclick={(e: MouseEvent) => handleColorClick(e, entry.key, entry.value)}
      >
        <span class="ic-ctx__color-swatch" style="background-color: {openColorKey === entry.key ? liveColor : (entry.value || 'var(--ic-muted-foreground)')}"></span>
        <span class="ic-ctx__label">{entry.label || entry.key}</span>
      </button>
      {#if openColorKey === entry.key}
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
          class="ic-ctx__color-picker"
          style:left="{colorPos.x}px"
          style:top="{colorPos.y}px"
          onclick={(e: MouseEvent) => e.stopPropagation()}
          onpointerdown={(e: PointerEvent) => e.stopPropagation()}
        >
          <SaturationValuePad
            hue={colorHue}
            bind:saturation={colorSatV}
            bind:valueBrightness={colorVal}
            onchange={() => emitColor(entry.key)}
          />
          <div class="ic-ctx__color-controls">
            <HueSlider bind:hue={colorHue} onchange={() => emitColor(entry.key)} />
          </div>
        </div>
      {/if}
    {:else if entry.type === 'range'}
      <div class="ic-ctx__range-entry">
        {#if entry.label}
          <span class="ic-ctx__range-label">{entry.label}</span>
        {/if}
        <input
          class="ic-ctx__range-input"
          type="range"
          value={entry.value}
          min={entry.min ?? 0}
          max={entry.max ?? 1}
          step={entry.step ?? 0.01}
          onclick={(e: MouseEvent) => e.stopPropagation()}
          oninput={(e: Event) => {
            const input = e.currentTarget as HTMLInputElement;
            const val = input.value;
            const display = input.nextElementSibling as HTMLElement;
            if (display) display.textContent = Math.round(Number(val) * 100) + '%';
            onaction(`${entry.key}:${val}`);
          }}
        />
        <span class="ic-ctx__range-value">{Math.round((entry.value ?? 0) * 100)}%</span>
      </div>
    {:else if entry.type === 'text'}
      <div class="ic-ctx__text-entry">
        {#if entry.label}
          <span class="ic-ctx__text-label">{entry.label}</span>
        {/if}
        <input
          class="ic-ctx__text-input"
          type="text"
          value={entry.value}
          placeholder={entry.placeholder || ''}
          spellcheck={false}
          autocomplete="off"
          onclick={(e: MouseEvent) => e.stopPropagation()}
          onkeydown={(e: KeyboardEvent) => {
            e.stopPropagation();
            if (e.key === 'Enter') {
              onaction(`${entry.key}:${(e.currentTarget as HTMLInputElement).value}`);
            }
          }}
          onblur={(e: FocusEvent) => {
            onaction(`${entry.key}:${(e.currentTarget as HTMLInputElement).value}`);
          }}
        />
      </div>
    {/if}
  {/each}
</div>

<style>
  .ic-ctx__panel {
    position: fixed;
    z-index: 200;
    min-width: 160px;
    padding: 3px 0;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.18);
  }

  .ic-ctx__item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 5px 10px 5px 8px;
    border: none;
    background: none;
    font-size: 0.8rem;
    font-family: inherit;
    color: var(--ic-foreground);
    cursor: pointer;
    white-space: nowrap;
    text-align: left;
  }
  .ic-ctx__item:hover {
    background: var(--ic-secondary);
  }
  .ic-ctx__item--disabled {
    opacity: 0.4;
    pointer-events: none;
  }

  .ic-ctx__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }

  .ic-ctx__label {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ic-ctx__shortcut {
    color: var(--ic-muted-foreground);
    font-size: 0.7rem;
    margin-left: auto;
    padding-left: 16px;
  }

  .ic-ctx__chevron {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    display: flex;
    align-items: center;
  }

  .ic-ctx__separator {
    margin: 3px 8px;
    border-top: 1px solid var(--ic-border);
  }

  /* ── Color entry ─────────────────────── */

  .ic-ctx__color-swatch {
    display: block;
    width: 14px;
    height: 14px;
    border-radius: 2px;
    flex-shrink: 0;
    border: 1px solid rgba(128, 128, 128, 0.3);
  }

  .ic-ctx__color-picker {
    position: fixed;
    z-index: 201;
    padding: 8px;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.18);
    min-width: 180px;
  }

  .ic-ctx__color-controls {
    padding-top: 6px;
  }

  /* ── Range entry ──────────────────────── */

  .ic-ctx__range-entry {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
  }

  .ic-ctx__range-label {
    font-size: 0.7rem;
    font-weight: 600;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .ic-ctx__range-input {
    flex: 1;
    min-width: 60px;
    height: 4px;
    accent-color: var(--ic-primary);
    cursor: pointer;
  }

  .ic-ctx__range-value {
    font-size: 0.7rem;
    color: var(--ic-muted-foreground);
    min-width: 28px;
    text-align: right;
    flex-shrink: 0;
  }

  /* ── Text entry ───────────────────────── */

  .ic-ctx__text-entry {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
  }

  .ic-ctx__text-label {
    font-size: 0.7rem;
    font-weight: 600;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .ic-ctx__text-input {
    flex: 1;
    min-width: 0;
    font-family: inherit;
    font-size: 0.8rem;
    color: var(--ic-foreground);
    background: var(--ic-background);
    border: 1px solid rgba(128, 128, 128, 0.15);
    border-radius: 2px;
    padding: 2px 5px;
    outline: none;
  }

  .ic-ctx__text-input:focus {
    border-color: var(--ic-primary);
  }
</style>
