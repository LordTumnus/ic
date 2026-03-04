<script lang="ts">
  import { untrack } from 'svelte';
  import type { DateFilterValue } from '$lib/utils/table-utils';

  let {
    initialValue,
    onchange,
  }: {
    initialValue?: unknown;
    onchange?: (value: unknown) => void;
  } = $props();

  type Mode = 'range' | 'isEmpty' | 'isNotEmpty';

  function detectMode(val: unknown): Mode {
    if (val && typeof val === 'object') {
      if ('isEmpty' in (val as Record<string, unknown>)) return 'isEmpty';
      if ('isNotEmpty' in (val as Record<string, unknown>)) return 'isNotEmpty';
    }
    return 'range';
  }

  const init = untrack(() => initialValue);
  const initMode = detectMode(init);
  let mode = $state<Mode>(initMode);
  let dateMin = $state(initMode === 'range' ? ((init as DateFilterValue)?.min ?? '') : '');
  let dateMax = $state(initMode === 'range' ? ((init as DateFilterValue)?.max ?? '') : '');
  let minEl = $state<HTMLInputElement>(null!);

  function emit() {
    if (mode === 'isEmpty') { onchange?.({ isEmpty: true }); return; }
    if (mode === 'isNotEmpty') { onchange?.({ isNotEmpty: true }); return; }
    const fv: DateFilterValue = {};
    if (dateMin) fv.min = dateMin;
    if (dateMax) fv.max = dateMax;
    onchange?.(fv.min || fv.max ? fv : null);
  }

  function toggleMode(m: 'isEmpty' | 'isNotEmpty') {
    mode = mode === m ? 'range' : m;
    emit();
    if (mode === 'range') requestAnimationFrame(() => minEl?.focus());
  }

  $effect(() => { if (mode === 'range') minEl?.focus(); });
</script>

{#if mode === 'range'}
  <div class="ic-tbl-fd__range">
    <label class="ic-tbl-fd__label">
      From
      <input
        bind:this={minEl}
        type="date"
        class="ic-tbl-fd__input"
        bind:value={dateMin}
        oninput={emit}
      />
    </label>
    <label class="ic-tbl-fd__label">
      To
      <input
        type="date"
        class="ic-tbl-fd__input"
        bind:value={dateMax}
        oninput={emit}
      />
    </label>
  </div>
{:else}
  <div class="ic-tbl-fd__hint">
    {mode === 'isEmpty' ? 'Showing empty cells' : 'Showing non-empty cells'}
  </div>
{/if}

<div class="ic-tbl-fn__pills">
  <button
    class="ic-tbl-fn__pill"
    class:ic-tbl-fn__pill--active={mode === 'isEmpty'}
    onclick={() => toggleMode('isEmpty')}
  >Empty</button>
  <button
    class="ic-tbl-fn__pill"
    class:ic-tbl-fn__pill--active={mode === 'isNotEmpty'}
    onclick={() => toggleMode('isNotEmpty')}
  >Has value</button>
</div>

<style>
  .ic-tbl-fd__range {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .ic-tbl-fd__label {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 0.65rem;
    color: var(--ic-muted-foreground);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .ic-tbl-fd__input {
    width: 100%;
    padding: 4px 6px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-background);
    color: var(--ic-foreground);
    font: inherit;
    font-size: 0.8rem;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
    box-sizing: border-box;
  }
  .ic-tbl-fd__input:focus {
    outline: none;
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
  }
  .ic-tbl-fd__hint {
    font-size: 0.7rem;
    color: var(--ic-muted-foreground);
    font-style: italic;
    text-align: center;
    padding: 4px 0;
  }
  /* Shared pill styles (same as NumberFilter) */
  .ic-tbl-fn__pills {
    display: flex;
    gap: 4px;
    margin-top: 6px;
  }
  .ic-tbl-fn__pill {
    flex: 1;
    padding: 3px 0;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    font: inherit;
    font-size: 0.65rem;
    cursor: pointer;
    text-align: center;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
    transition: all 0.1s ease;
  }
  .ic-tbl-fn__pill:hover {
    background: var(--ic-muted);
    color: var(--ic-foreground);
  }
  .ic-tbl-fn__pill--active {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    border-color: var(--ic-primary);
    box-shadow: none;
  }
</style>
