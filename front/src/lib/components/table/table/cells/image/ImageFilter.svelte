<script lang="ts">
  import { untrack } from 'svelte';

  let {
    initialValue,
    onchange,
  }: {
    initialValue?: unknown;
    onchange?: (value: unknown) => void;
  } = $props();

  type Mode = 'all' | 'isEmpty' | 'isNotEmpty';

  function detectMode(val: unknown): Mode {
    if (val && typeof val === 'object') {
      if ('isEmpty' in (val as Record<string, unknown>)) return 'isEmpty';
      if ('isNotEmpty' in (val as Record<string, unknown>)) return 'isNotEmpty';
    }
    return 'all';
  }

  const init = untrack(() => initialValue);
  let mode = $state<Mode>(detectMode(init));

  function toggle(m: 'isEmpty' | 'isNotEmpty') {
    mode = mode === m ? 'all' : m;
    if (mode === 'isEmpty') { onchange?.({ isEmpty: true }); return; }
    if (mode === 'isNotEmpty') { onchange?.({ isNotEmpty: true }); return; }
    onchange?.(null);
  }
</script>

{#if mode !== 'all'}
  <div class="ic-tbl-fn__hint">
    {mode === 'isEmpty' ? 'Showing empty cells' : 'Showing cells with image'}
  </div>
{/if}

<div class="ic-tbl-fn__pills">
  <button
    class="ic-tbl-fn__pill"
    class:ic-tbl-fn__pill--active={mode === 'isEmpty'}
    onclick={() => toggle('isEmpty')}
  >Empty</button>
  <button
    class="ic-tbl-fn__pill"
    class:ic-tbl-fn__pill--active={mode === 'isNotEmpty'}
    onclick={() => toggle('isNotEmpty')}
  >Has image</button>
</div>

<style>
  .ic-tbl-fn__hint {
    font-size: 0.7rem;
    color: var(--ic-muted-foreground);
    font-style: italic;
    text-align: center;
    padding: 4px 0;
  }
  .ic-tbl-fn__pills {
    display: flex;
    gap: 4px;
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
