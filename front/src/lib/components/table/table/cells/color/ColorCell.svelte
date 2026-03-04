<script lang="ts">
  import type { ColorConfig } from '$lib/utils/table-utils';
  import { parseColor, formatColor, hslToHsv, hsvToHsl, hslToRgb, rgbToHex } from '$lib/utils/color';
  import SaturationValuePad from '$lib/components/form/colorPicker/SaturationValuePad.svelte';
  import HueSlider from '$lib/components/form/colorPicker/HueSlider.svelte';
  import AlphaSlider from '$lib/components/form/colorPicker/AlphaSlider.svelte';
  import PresetSwatches from '$lib/components/form/colorPicker/PresetSwatches.svelte';

  let {
    value,
    config = {} as Partial<ColorConfig>,
    style = $bindable(''),
    editing = false,
    oncommitedit,
    oncanceledit,
  }: {
    value?: unknown;
    config?: Partial<ColorConfig>;
    style?: string;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
  } = $props();

  // ── Config ───────────────────────────────────────
  const fmt = $derived(config.format ?? 'hex');
  const showAlpha = $derived(config.showAlpha ?? false);
  const presets = $derived(config.presets ?? []);

  // ── Display value ────────────────────────────────
  const strVal = $derived(value != null && value !== '' ? String(value) : '');
  const hasValue = $derived(strVal !== '');

  const parsed = $derived(hasValue ? parseColor(strVal) : null);
  const displayColor = $derived(
    parsed
      ? `hsla(${parsed.h}, ${parsed.s}%, ${parsed.l}%, ${parsed.a})`
      : 'transparent'
  );

  // Hex tooltip on hover
  const hexTooltip = $derived.by((): string => {
    if (!parsed) return '';
    const { r, g, b } = hslToRgb(parsed.h, parsed.s, parsed.l);
    return rgbToHex(r, g, b, parsed.a);
  });

  // No cell background tinting for color columns
  $effect(() => { style = ''; });

  // ── Hover tooltip ────────────────────────────────
  let title = $state('');
  function onenter() { title = hexTooltip; }
  function onleave() { title = ''; }

  // ── Edit mode ────────────────────────────────────
  let anchorEl = $state<HTMLElement>(null!);
  let popupEl = $state<HTMLElement>(null!);
  let pos = $state<{ top: number; left: number } | null>(null);

  // Internal HSV state (same pattern as ColorPicker.svelte)
  let internalHue = $state(0);
  let internalSatV = $state(100);
  let internalVal = $state(100);
  let internalAlpha = $state(1);

  // Parse value into HSV when editing starts
  $effect(() => {
    if (editing && hasValue) {
      const p = parseColor(strVal);
      const hsv = hslToHsv(p.h, p.s, p.l);
      internalHue = hsv.h;
      internalSatV = hsv.s;
      internalVal = hsv.v;
      internalAlpha = showAlpha ? p.a : 1;
    }
  });

  // Derived HSL from internal HSV
  const internalHsl = $derived(hsvToHsl(internalHue, internalSatV, internalVal));
  const previewColor = $derived(
    `hsla(${internalHsl.h}, ${internalHsl.s}%, ${internalHsl.l}%, ${internalAlpha})`
  );
  const opaqueColor = $derived(
    `hsl(${internalHsl.h}, ${internalHsl.s}%, ${internalHsl.l}%)`
  );

  // Position the popup
  const POPUP_W = 220;
  const POPUP_H = 280;

  $effect(() => {
    if (editing && anchorEl) {
      const rect = anchorEl.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      const spaceRight = window.innerWidth - rect.left;
      const flipUp = spaceBelow < POPUP_H && rect.top > POPUP_H;
      const flipLeft = spaceRight < POPUP_W && rect.left > POPUP_W;
      pos = {
        top: flipUp ? rect.top - POPUP_H - 2 : rect.bottom + 2,
        left: flipLeft ? rect.right - POPUP_W : rect.left,
      };
    } else {
      pos = null;
    }
  });

  // Click-outside → commit
  $effect(() => {
    if (!editing) return;
    const handler = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (!target.closest('.ic-tbl-cell-color__popup') &&
          !target.closest('.ic-tbl-cell-color__anchor')) {
        commitColor();
      }
    };
    const timer = setTimeout(() => {
      document.addEventListener('mousedown', handler, true);
    }, 0);
    return () => {
      clearTimeout(timer);
      document.removeEventListener('mousedown', handler, true);
    };
  });

  function commitColor() {
    const hsl = hsvToHsl(internalHue, internalSatV, internalVal);
    const newValue = formatColor(hsl.h, hsl.s, hsl.l, internalAlpha, fmt, showAlpha);
    oncommitedit?.(value, newValue);
  }

  function handleKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    if (e.key === 'Escape') {
      e.preventDefault();
      oncanceledit?.();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      commitColor();
    }
  }

  // Sub-component change handlers (live preview is automatic via derived state)
  function handlePadChange() {}
  function handleHueChange() {}
  function handleAlphaChange() {}

  function handlePresetSelect(color: string) {
    const p = parseColor(color);
    const hsv = hslToHsv(p.h, p.s, p.l);
    internalHue = hsv.h;
    internalSatV = hsv.s;
    internalVal = hsv.v;
    internalAlpha = showAlpha ? p.a : 1;
  }

  function autofocus(node: HTMLElement) {
    requestAnimationFrame(() => node.focus());
  }
</script>

{#if editing}
  <div
    bind:this={anchorEl}
    class="ic-tbl-cell-color__anchor"
    onkeydown={handleKeydown}
    onclick={(e: MouseEvent) => e.stopPropagation()}
    ondblclick={(e: MouseEvent) => e.stopPropagation()}
    use:autofocus
    tabindex={0}
    role="button"
    aria-expanded={pos != null}
  >
    <div class="ic-tbl-cell-color__swatch ic-tbl-cell-color__swatch--active">
      <div class="ic-tbl-cell-color__checker"></div>
      <div class="ic-tbl-cell-color__fill" style="background-color: {previewColor}"></div>
    </div>
  </div>

  {#if pos}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div
      bind:this={popupEl}
      class="ic-tbl-cell-color__popup"
      role="dialog"
      tabindex={-1}
      style="top:{pos.top}px; left:{pos.left}px;"
      onmousedown={(e) => { e.preventDefault(); e.stopPropagation(); }}
      onclick={(e: MouseEvent) => e.stopPropagation()}
      ondblclick={(e: MouseEvent) => e.stopPropagation()}
    >
      <SaturationValuePad
        hue={internalHue}
        bind:saturation={internalSatV}
        bind:valueBrightness={internalVal}
        onchange={handlePadChange}
      />
      <div class="ic-tbl-cell-color__controls">
        <HueSlider bind:hue={internalHue} onchange={handleHueChange} />
        {#if showAlpha}
          <AlphaSlider
            bind:alpha={internalAlpha}
            color={opaqueColor}
            onchange={handleAlphaChange}
          />
        {/if}
        {#if presets.length > 0}
          <PresetSwatches {presets} onselect={handlePresetSelect} />
        {/if}
      </div>
    </div>
  {/if}
{:else if hasValue}
  <div
    class="ic-tbl-cell-color__swatch"
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >
    <div class="ic-tbl-cell-color__checker"></div>
    <div class="ic-tbl-cell-color__fill" style="background-color: {displayColor}"></div>
  </div>
{:else}
  <span class="ic-tbl-cell-color__empty"></span>
{/if}

<style>
  /* ── Swatch ───────────────────────────────── */
  .ic-tbl-cell-color__swatch {
    position: relative;
    width: 22px;
    height: 16px;
    border-radius: 2px;
    overflow: hidden;
    flex-shrink: 0;
    border: 1px solid rgba(0, 0, 0, 0.15);
    box-shadow:
      inset 0 1px 2px rgba(0, 0, 0, 0.18),
      inset 0 -1px 0 rgba(255, 255, 255, 0.04);
    cursor: default;
  }

  .ic-tbl-cell-color__swatch--active {
    box-shadow:
      inset 0 1px 2px rgba(0, 0, 0, 0.18),
      0 0 0 1px var(--ic-primary);
  }

  .ic-tbl-cell-color__checker {
    position: absolute;
    inset: 0;
    background-image:
      linear-gradient(45deg, #ccc 25%, transparent 25%),
      linear-gradient(-45deg, #ccc 25%, transparent 25%),
      linear-gradient(45deg, transparent 75%, #ccc 75%),
      linear-gradient(-45deg, transparent 75%, #ccc 75%);
    background-size: 6px 6px;
    background-position: 0 0, 0 3px, 3px -3px, -3px 0px;
  }

  .ic-tbl-cell-color__fill {
    position: absolute;
    inset: 0;
  }

  .ic-tbl-cell-color__empty {
    width: 22px;
    height: 16px;
    display: inline-block;
    border-radius: 2px;
    border: 1px dashed var(--ic-border);
  }

  /* ── Edit anchor ──────────────────────────── */
  .ic-tbl-cell-color__anchor {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
    border-radius: 2px;
    cursor: pointer;
  }
  .ic-tbl-cell-color__anchor:focus {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
  }

  /* ── Popup ────────────────────────────────── */
  .ic-tbl-cell-color__popup {
    position: fixed;
    z-index: 9999;
    width: 220px;
    display: flex;
    flex-direction: column;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }

  /* ── Controls (sliders + presets below pad) ── */
  .ic-tbl-cell-color__controls {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 8px 10px 10px;
  }
</style>
