<script lang="ts">
  import { untrack } from 'svelte';

  let {
    initialValue,
    onchange,
  }: {
    initialValue?: unknown;
    onchange?: (value: unknown) => void;
  } = $props();

  type Mode = 'search' | 'isEmpty' | 'isNotEmpty';

  function detectMode(val: unknown): Mode {
    if (val && typeof val === 'object') {
      if ('isEmpty' in (val as Record<string, unknown>)) return 'isEmpty';
      if ('isNotEmpty' in (val as Record<string, unknown>)) return 'isNotEmpty';
    }
    return 'search';
  }

  const init = untrack(() => initialValue);
  const initMode = detectMode(init);
  let mode = $state<Mode>(initMode);
  let text = $state(initMode === 'search' ? String(init ?? '') : '');
  let inputEl = $state<HTMLInputElement>(null!);

  function emit() {
    if (mode === 'isEmpty') onchange?.({ isEmpty: true });
    else if (mode === 'isNotEmpty') onchange?.({ isNotEmpty: true });
    else onchange?.(text || null);
  }

  function toggleMode(m: 'isEmpty' | 'isNotEmpty') {
    mode = mode === m ? 'search' : m;
    emit();
    if (mode === 'search') requestAnimationFrame(() => inputEl?.focus());
  }

  $effect(() => { if (mode === 'search') inputEl?.focus(); });
</script>

{#if mode === 'search'}
  <input
    bind:this={inputEl}
    type="text"
    class="ic-tbl-ft__input"
    bind:value={text}
    oninput={emit}
    placeholder="Contains..."
  />
{:else}
  <div class="ic-tbl-ft__hint">
    {mode === 'isEmpty' ? 'Showing empty cells' : 'Showing non-empty cells'}
  </div>
{/if}

<div class="ic-tbl-ft__pills">
  <button
    class="ic-tbl-ft__pill"
    class:ic-tbl-ft__pill--active={mode === 'isEmpty'}
    onclick={() => toggleMode('isEmpty')}
  >Empty</button>
  <button
    class="ic-tbl-ft__pill"
    class:ic-tbl-ft__pill--active={mode === 'isNotEmpty'}
    onclick={() => toggleMode('isNotEmpty')}
  >Has value</button>
</div>

<style>
  .ic-tbl-ft__input {
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
  .ic-tbl-ft__input:focus {
    outline: none;
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
  }
  .ic-tbl-ft__hint {
    font-size: 0.7rem;
    color: var(--ic-muted-foreground);
    font-style: italic;
    text-align: center;
    padding: 4px 0;
  }
  .ic-tbl-ft__pills {
    display: flex;
    gap: 4px;
    margin-top: 6px;
  }
  .ic-tbl-ft__pill {
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
  .ic-tbl-ft__pill:hover {
    background: var(--ic-muted);
    color: var(--ic-foreground);
  }
  .ic-tbl-ft__pill--active {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    border-color: var(--ic-primary);
    box-shadow: none;
  }
</style>
