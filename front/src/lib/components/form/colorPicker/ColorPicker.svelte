<script lang="ts">
  import { untrack } from 'svelte';
  import type { Resolution } from '$lib/types';
  import { parseColor, formatColor, hslToHsv, hsvToHsl } from '$lib/utils/color';
  import SaturationValuePad from './SaturationValuePad.svelte';
  import HueSlider from './HueSlider.svelte';
  import AlphaSlider from './AlphaSlider.svelte';
  import PresetSwatches from './PresetSwatches.svelte';
  import ColorInput from './ColorInput.svelte';

  let {
    value = $bindable('#3b82f6'),
    showAlpha = $bindable(false),
    format = $bindable('hex'),
    showLabel = $bindable(false),
    disabled = $bindable(false),
    size = $bindable('md'),
    presets = $bindable([]),
    popupPosition = $bindable('best'),
    valueChanging,
    opened,
    closed,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: string;
    showAlpha?: boolean;
    format?: string;
    showLabel?: boolean;
    disabled?: boolean;
    size?: string;
    presets?: string | string[];
    popupPosition?: string;
    valueChanging?: (data?: unknown) => void;
    opened?: (data?: unknown) => void;
    closed?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  // --- Refs & state ---
  let swatchEl: HTMLDivElement;
  let popupEl = $state<HTMLDivElement>();
  let isOpen = $state(false);
  let isFocused = $state(false);

  // --- Internal HSV + alpha state (the pad works in HSV space) ---
  let internalHue = $state(0);
  let internalSatV = $state(100);  // HSV saturation (0-100)
  let internalVal = $state(100);   // HSV value/brightness (0-100)
  let internalAlpha = $state(1);   // 0-1

  // Sync suppression flag to prevent value → parse → format → value loops
  let suppressSync = false;

  // --- Parse value into internal HSV+A when it changes externally ---
  $effect(() => {
    const v = value; // track dependency
    if (suppressSync) return;
    const parsed = parseColor(v);
    const hsv = hslToHsv(parsed.h, parsed.s, parsed.l);
    internalHue = hsv.h;
    internalSatV = hsv.s;
    internalVal = hsv.v;
    internalAlpha = showAlpha ? parsed.a : 1;
  });

  // --- Convert internal HSV → HSL for display and formatting ---
  const internalHsl = $derived(hsvToHsl(internalHue, internalSatV, internalVal));

  const displayColor = $derived(
    `hsla(${internalHsl.h}, ${internalHsl.s}%, ${internalHsl.l}%, ${internalAlpha})`
  );

  const opaqueColor = $derived(
    `hsl(${internalHsl.h}, ${internalHsl.s}%, ${internalHsl.l}%)`
  );

  const labelText = $derived(
    formatColor(internalHsl.h, internalHsl.s, internalHsl.l, internalAlpha, format, showAlpha)
  );

  // Normalize presets: accept a single string or string[]
  const presetList = $derived(
    Array.isArray(presets) ? presets : (typeof presets === 'string' && presets ? [presets] : [])
  );

  const hasPresets = $derived(presetList.length > 0);

  // --- Popup positioning ---
  let rootEl: HTMLDivElement;
  let resolvedPosition = $state('bottom');

  function computeBestPosition(): string {
    if (!rootEl) return 'bottom';
    const rect = rootEl.getBoundingClientRect();
    const gap = 4;
    const popupW = 220;
    const popupH = 300;

    const below = window.innerHeight - rect.bottom - gap;
    const above = rect.top - gap;
    const right = window.innerWidth - rect.right - gap;
    const left = rect.left - gap;

    // Priority: bottom > top > right > left
    if (below >= popupH) return 'bottom';
    if (above >= popupH) return 'top';
    if (right >= popupW) return 'right';
    if (left >= popupW) return 'left';

    return below >= above ? 'bottom' : 'top';
  }

  const popupStyle = $derived.by(() => {
    const pos = popupPosition === 'best' ? resolvedPosition : popupPosition;
    switch (pos) {
      case 'top': return 'bottom: calc(100% + 4px); left: 0;';
      case 'right': return 'top: 0; left: calc(100% + 4px);';
      case 'left': return 'top: 0; right: calc(100% + 4px);';
      default: return 'top: calc(100% + 4px); left: 0;';
    }
  });

  // --- Emit formatted value ---
  function emitValue() {
    suppressSync = true;
    const hsl = hsvToHsl(internalHue, internalSatV, internalVal);
    value = formatColor(hsl.h, hsl.s, hsl.l, internalAlpha, format, showAlpha);
    valueChanging?.({ value });
    queueMicrotask(() => { suppressSync = false; });
  }

  // --- Change handlers ---
  function handlePadChange() {
    emitValue();
  }

  function handleHueChange() {
    emitValue();
  }

  function handleAlphaChange() {
    emitValue();
  }

  // --- Input field editing ---
  function handleInputChange(h: number, s: number, l: number, a: number) {
    const hsv = hslToHsv(h, s, l);
    internalHue = hsv.h;
    internalSatV = hsv.s;
    internalVal = hsv.v;
    internalAlpha = a;
    emitValue();
  }

  // --- Re-emit value when format changes ---
  let formatInit = false;
  $effect(() => {
    const fmt = format;
    if (!formatInit) { formatInit = true; return; }
    untrack(() => {
      suppressSync = true;
      const hsl = hsvToHsl(internalHue, internalSatV, internalVal);
      value = formatColor(hsl.h, hsl.s, hsl.l, internalAlpha, fmt, showAlpha);
      queueMicrotask(() => { suppressSync = false; });
    });
  });

  // --- Re-emit value when showAlpha toggles ---
  let showAlphaInit = false;
  $effect(() => {
    const sa = showAlpha;
    if (!showAlphaInit) { showAlphaInit = true; return; }
    if (!sa) internalAlpha = 1;
    untrack(() => {
      suppressSync = true;
      const hsl = hsvToHsl(internalHue, internalSatV, internalVal);
      value = formatColor(hsl.h, hsl.s, hsl.l, internalAlpha, format, sa);
      queueMicrotask(() => { suppressSync = false; });
    });
  });

  // --- Preset selection ---
  function handlePresetSelect(color: string) {
    const parsed = parseColor(color);
    const hsv = hslToHsv(parsed.h, parsed.s, parsed.l);
    internalHue = hsv.h;
    internalSatV = hsv.s;
    internalVal = hsv.v;
    internalAlpha = showAlpha ? parsed.a : 1;
    emitValue();
  }

  // --- Popup open/close ---
  function togglePopup() {
    if (disabled) return;
    isOpen = !isOpen;
    if (isOpen) {
      if (popupPosition === 'best') {
        resolvedPosition = computeBestPosition();
      }
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
    const target = e.target as Node;
    if (popupEl && !popupEl.contains(target) && swatchEl && !swatchEl.contains(target)) {
      closePopup();
    }
  }

  // --- Keyboard on swatch ---
  function handleSwatchKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      togglePopup();
    } else if (e.key === 'Escape') {
      closePopup();
    }
  }

  // --- Focus management ---
  $effect(() => {
    focus = (): Resolution => {
      swatchEl?.focus();
      return { success: true, data: null };
    };
  });
</script>

<div
  bind:this={rootEl}
  class="ic-color-picker"
  class:ic-color-picker--sm={size === 'sm'}
  class:ic-color-picker--md={size === 'md'}
  class:ic-color-picker--lg={size === 'lg'}
  class:ic-color-picker--disabled={disabled}
  class:ic-color-picker--open={isOpen}
>
  <!-- Field: swatch + optional inputs -->
  <div
    class="ic-color-picker__field"
    class:ic-color-picker__field--grouped={showLabel}
    class:ic-color-picker__field--focused={isFocused}
  >
    <div
      bind:this={swatchEl}
      class="ic-color-picker__swatch"
      class:ic-color-picker__swatch--standalone={!showLabel}
      class:ic-color-picker__swatch--focused={isFocused}
      role="button"
      tabindex={disabled ? -1 : 0}
      onclick={togglePopup}
      onkeydown={handleSwatchKeydown}
      onfocus={() => (isFocused = true)}
      onblur={() => (isFocused = false)}
      aria-expanded={isOpen}
      aria-label="Color picker: {labelText}"
    >
      <div class="ic-color-picker__checker"></div>
      <div class="ic-color-picker__swatch-fill" style="background-color: {displayColor}"></div>
    </div>
    {#if showLabel}
      <ColorInput
        hue={internalHsl.h}
        saturation={internalHsl.s}
        lightness={internalHsl.l}
        alpha={internalAlpha}
        {showAlpha}
        {format}
        {disabled}
        onchange={handleInputChange}
      />
    {/if}
  </div>

  <!-- Popup -->
  {#if isOpen}
    <div bind:this={popupEl} class="ic-color-picker__popup" style={popupStyle}>
      <SaturationValuePad
        hue={internalHue}
        bind:saturation={internalSatV}
        bind:valueBrightness={internalVal}
        {disabled}
        onchange={handlePadChange}
      />
      <div class="ic-color-picker__controls">
        <HueSlider bind:hue={internalHue} {disabled} onchange={handleHueChange} />
        {#if showAlpha}
          <AlphaSlider bind:alpha={internalAlpha} {disabled} color={opaqueColor} onchange={handleAlphaChange} />
        {/if}
        {#if hasPresets}
          <PresetSwatches presets={presetList} onselect={handlePresetSelect} />
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  /* ── Root ──────────────────────────────── */
  .ic-color-picker {
    display: inline-flex;
    align-items: center;
    position: relative;
    font-family: inherit;
  }

  /* ── Field container ────────────────────── */
  .ic-color-picker__field {
    display: inline-flex;
    align-items: center;
  }

  .ic-color-picker__field--grouped {
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
    padding: 3px;
    padding-right: 8px;
    gap: 8px;
    transition: border-color 0.15s ease;
  }

  .ic-color-picker__field--grouped.ic-color-picker__field--focused {
    border-color: var(--ic-primary);
  }

  /* ── Swatch ─────────────────────────────── */
  .ic-color-picker__swatch {
    position: relative;
    border-radius: 2px;
    cursor: pointer;
    overflow: hidden;
    outline: none;
    flex-shrink: 0;
  }

  /* Standalone: swatch has its own elevation */
  .ic-color-picker__swatch--standalone {
    border: 1px solid transparent;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .ic-color-picker__swatch--standalone.ic-color-picker__swatch--focused {
    box-shadow:
      0 2px 8px rgba(0, 0, 0, 0.4),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-color-picker__swatch--standalone:hover:not(.ic-color-picker--disabled .ic-color-picker__swatch) {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.28),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
  }

  /* ── Size variants ─────────────────────── */
  .ic-color-picker--sm .ic-color-picker__swatch { width: 16px; height: 16px; }
  .ic-color-picker--md .ic-color-picker__swatch { width: 20px; height: 20px; }
  .ic-color-picker--lg .ic-color-picker__swatch { width: 28px; height: 28px; }

  /* ── Swatch internals ──────────────────── */
  .ic-color-picker__checker {
    position: absolute;
    inset: 0;
    border-radius: inherit;
    background-image:
      linear-gradient(45deg, #ccc 25%, transparent 25%),
      linear-gradient(-45deg, #ccc 25%, transparent 25%),
      linear-gradient(45deg, transparent 75%, #ccc 75%),
      linear-gradient(-45deg, transparent 75%, #ccc 75%);
    background-size: 8px 8px;
    background-position: 0 0, 0 4px, 4px -4px, -4px 0px;
  }

  .ic-color-picker__swatch-fill {
    position: absolute;
    inset: 0;
    border-radius: inherit;
  }

  /* ── Popup ─────────────────────────────── */
  .ic-color-picker__popup {
    position: absolute;
    z-index: 50;
    display: flex;
    flex-direction: column;
    min-width: 200px;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    overflow: hidden;
  }

  /* ── Controls (sliders + presets below the pad) ── */
  .ic-color-picker__controls {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 8px 10px 10px;
  }

  /* ── Disabled ──────────────────────────── */
  .ic-color-picker--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-color-picker--disabled .ic-color-picker__swatch {
    cursor: not-allowed;
  }
</style>
