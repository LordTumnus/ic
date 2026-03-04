<script lang="ts">
  import { untrack } from 'svelte';

  let {
    initialValue,
    onchange,
  }: {
    initialValue?: unknown;
    onchange?: (value: unknown) => void;
  } = $props();

  const init = untrack(() => initialValue) as boolean | null;
  let selected = $state<boolean | null>(init ?? null);

  function select(val: boolean | null) {
    selected = val;
    onchange?.(val);
  }
</script>

<div class="ic-tbl-fb__seg">
  <button
    class="ic-tbl-fb__btn"
    class:ic-tbl-fb__btn--active={selected === null}
    onclick={() => select(null)}
  >All</button>
  <button
    class="ic-tbl-fb__btn"
    class:ic-tbl-fb__btn--active={selected === true}
    onclick={() => select(true)}
  >True</button>
  <button
    class="ic-tbl-fb__btn"
    class:ic-tbl-fb__btn--active={selected === false}
    onclick={() => select(false)}
  >False</button>
</div>

<style>
  .ic-tbl-fb__seg {
    display: flex;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: hidden;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
  }
  .ic-tbl-fb__btn {
    flex: 1;
    padding: 4px 0;
    border: none;
    border-right: 1px solid var(--ic-border);
    background: var(--ic-secondary);
    color: var(--ic-foreground);
    font: inherit;
    font-size: 0.75rem;
    cursor: pointer;
    text-align: center;
    transition: all 0.1s ease;
  }
  .ic-tbl-fb__btn:last-child {
    border-right: none;
  }
  .ic-tbl-fb__btn:hover {
    background: var(--ic-muted);
  }
  .ic-tbl-fb__btn--active {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    box-shadow: none;
  }
  .ic-tbl-fb__btn--active:hover {
    background: var(--ic-primary);
  }
</style>
