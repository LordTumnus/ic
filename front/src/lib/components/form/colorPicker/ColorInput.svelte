<script lang="ts">
  import { hslToRgb, rgbToHsl, rgbToHex, hexToRgb } from '$lib/utils/color';

  let {
    hue = 0,
    saturation = 0,
    lightness = 0,
    alpha = 1,
    showAlpha = false,
    format = 'hex',
    disabled = false,
    onchange,
  }: {
    hue?: number;
    saturation?: number;
    lightness?: number;
    alpha?: number;
    showAlpha?: boolean;
    format?: string;
    disabled?: boolean;
    onchange?: (h: number, s: number, l: number, a: number) => void;
  } = $props();

  const rgb = $derived(hslToRgb(hue, saturation, lightness));
  const hexStr = $derived(rgbToHex(rgb.r, rgb.g, rgb.b, alpha));

  // --- Hex editing state (prevents value clobbering while user types) ---
  let hexLocal = $state('');
  let hexFocused = $state(false);

  $effect(() => {
    if (!hexFocused) hexLocal = hexStr;
  });

  function commitHex() {
    hexFocused = false;
    let v = hexLocal.trim();
    if (!v.startsWith('#')) v = '#' + v;
    const p = hexToRgb(v);
    const hsl = rgbToHsl(p.r, p.g, p.b);
    onchange?.(hsl.h, hsl.s, hsl.l, p.a);
  }

  function commitRgb(ch: 'r' | 'g' | 'b', e: Event) {
    const v = clampInt(+(e.currentTarget as HTMLInputElement).value, 0, 255);
    const r = ch === 'r' ? v : rgb.r;
    const g = ch === 'g' ? v : rgb.g;
    const b = ch === 'b' ? v : rgb.b;
    const hsl = rgbToHsl(r, g, b);
    onchange?.(hsl.h, hsl.s, hsl.l, alpha);
  }

  function commitHsl(ch: 'h' | 's' | 'l', e: Event) {
    const raw = +(e.currentTarget as HTMLInputElement).value;
    const max = ch === 'h' ? 360 : 100;
    const h = ch === 'h' ? clampInt(raw, 0, max) : hue;
    const s = ch === 's' ? clampInt(raw, 0, max) : saturation;
    const l = ch === 'l' ? clampInt(raw, 0, max) : lightness;
    onchange?.(h, s, l, alpha);
  }

  function commitAlpha(e: Event) {
    const v = Math.round(Math.max(0, Math.min(1, +(e.currentTarget as HTMLInputElement).value)) * 100) / 100;
    onchange?.(hue, saturation, lightness, v);
  }

  function blurOnEnter(e: KeyboardEvent) {
    if (e.key === 'Enter') (e.currentTarget as HTMLElement).blur();
  }

  function clampInt(v: number, min: number, max: number): number {
    return Math.round(Math.max(min, Math.min(max, v)));
  }
</script>

<div class="ic-cp-input">
  {#if format === 'hex'}
    <input
      class="ic-cp-input__field ic-cp-input__field--hex"
      type="text"
      value={hexLocal}
      oninput={(e) => { hexFocused = true; hexLocal = e.currentTarget.value; }}
      onfocus={() => (hexFocused = true)}
      onblur={commitHex}
      onkeydown={blurOnEnter}
      {disabled}
      spellcheck={false}
      autocomplete="off"
    />
  {:else if format === 'rgb'}
    <label class="ic-cp-input__channel">
      <span class="ic-cp-input__channel-label">R</span>
      <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={255} value={rgb.r} onchange={(e) => commitRgb('r', e)} onkeydown={blurOnEnter} {disabled} />
    </label>
    <label class="ic-cp-input__channel">
      <span class="ic-cp-input__channel-label">G</span>
      <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={255} value={rgb.g} onchange={(e) => commitRgb('g', e)} onkeydown={blurOnEnter} {disabled} />
    </label>
    <label class="ic-cp-input__channel">
      <span class="ic-cp-input__channel-label">B</span>
      <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={255} value={rgb.b} onchange={(e) => commitRgb('b', e)} onkeydown={blurOnEnter} {disabled} />
    </label>
    {#if showAlpha}
      <label class="ic-cp-input__channel">
        <span class="ic-cp-input__channel-label">A</span>
        <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={1} step={0.01} value={alpha} onchange={commitAlpha} onkeydown={blurOnEnter} {disabled} />
      </label>
    {/if}
  {:else if format === 'hsl'}
    <label class="ic-cp-input__channel">
      <span class="ic-cp-input__channel-label">H</span>
      <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={360} value={hue} onchange={(e) => commitHsl('h', e)} onkeydown={blurOnEnter} {disabled} />
    </label>
    <label class="ic-cp-input__channel">
      <span class="ic-cp-input__channel-label">S</span>
      <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={100} value={saturation} onchange={(e) => commitHsl('s', e)} onkeydown={blurOnEnter} {disabled} />
    </label>
    <label class="ic-cp-input__channel">
      <span class="ic-cp-input__channel-label">L</span>
      <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={100} value={lightness} onchange={(e) => commitHsl('l', e)} onkeydown={blurOnEnter} {disabled} />
    </label>
    {#if showAlpha}
      <label class="ic-cp-input__channel">
        <span class="ic-cp-input__channel-label">A</span>
        <input class="ic-cp-input__field ic-cp-input__field--num" type="number" min={0} max={1} step={0.01} value={alpha} onchange={commitAlpha} onkeydown={blurOnEnter} {disabled} />
      </label>
    {/if}
  {/if}
</div>

<style>
  .ic-cp-input {
    display: flex;
    align-items: center;
    gap: 6px;
    min-width: 10rem;
  }

  .ic-cp-input__channel {
    display: flex;
    align-items: center;
    gap: 3px;
    cursor: text;
    flex: 1;
    min-width: 0;
  }

  .ic-cp-input__channel-label {
    font-size: 0.6875rem;
    font-weight: 700;
    color: var(--ic-foreground);
    user-select: none;
    line-height: 1;
  }

  .ic-cp-input__field {
    font-family: inherit;
    font-size: 0.75rem;
    font-variant-numeric: tabular-nums;
    color: var(--ic-foreground);
    background: var(--ic-background);
    border: 1px solid rgba(128, 128, 128, 0.15);
    border-radius: 2px;
    padding: 2px 4px;
    outline: none;
    transition: border-color 0.15s ease;
  }

  .ic-cp-input__field:focus {
    border-color: var(--ic-primary);
  }

  .ic-cp-input__field--hex {
    flex: 1;
    min-width: 0;
  }

  .ic-cp-input__field--num {
    flex: 1;
    min-width: 0;
    text-align: center;
    -moz-appearance: textfield;
  }

  .ic-cp-input__field--num::-webkit-inner-spin-button,
  .ic-cp-input__field--num::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }
</style>
