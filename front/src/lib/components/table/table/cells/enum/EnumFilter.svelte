<script lang="ts">
  import type { EnumConfig } from '$lib/utils/table-utils';
  import { buildEnumColorMap } from '$lib/utils/table-utils';
  import { untrack } from 'svelte';
  import { SvelteSet } from 'svelte/reactivity';

  let {
    initialValue,
    config = {} as Partial<EnumConfig>,
    onchange,
  }: {
    initialValue?: unknown;
    config?: Partial<EnumConfig>;
    onchange?: (value: unknown) => void;
  } = $props();

  const items = untrack(() => config?.items ?? []);
  const colorMap = untrack(() => buildEnumColorMap(config ?? {}));

  // Initialize checked set from filter value
  const init = untrack(() => initialValue);
  const checked = new SvelteSet<string>(
    Array.isArray(init) ? (init as string[]) : items,
  );

  const allChecked = $derived(checked.size === items.length);
  const noneChecked = $derived(checked.size === 0);

  function toggle(item: string) {
    if (checked.has(item)) checked.delete(item);
    else checked.add(item);
    emit();
  }

  function selectAll() {
    for (const item of items) checked.add(item);
    onchange?.(null);
  }

  function clearAll() {
    checked.clear();
    onchange?.(null);
  }

  function emit() {
    if (checked.size === items.length || checked.size === 0) {
      onchange?.(null);
    } else {
      onchange?.([...checked]);
    }
  }

  /** Convert hex to rgba for the colored dot. */
  function hexToRgba(hex: string, alpha: number): string {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
</script>

<div class="ic-tbl-fe">
  <div class="ic-tbl-fe__actions">
    <button
      class="ic-tbl-fe__link"
      disabled={allChecked}
      onclick={selectAll}
    >Select all</button>
    <button
      class="ic-tbl-fe__link"
      disabled={noneChecked}
      onclick={clearAll}
    >Clear</button>
  </div>

  <div class="ic-tbl-fe__list">
    {#each items as item (item)}
      {@const color = colorMap[item] ?? ''}
      <label class="ic-tbl-fe__item">
        <input
          type="checkbox"
          class="ic-tbl-fe__cb"
          checked={checked.has(item)}
          onchange={() => toggle(item)}
        />
        {#if color}
          <span
            class="ic-tbl-fe__dot"
            style="background:{color};box-shadow:0 0 0 1px {hexToRgba(color, 0.3)};"
          ></span>
        {:else}
          <span class="ic-tbl-fe__dot ic-tbl-fe__dot--muted"></span>
        {/if}
        <span class="ic-tbl-fe__label">{item}</span>
      </label>
    {/each}
  </div>
</div>

<style>
  .ic-tbl-fe__actions {
    display: flex;
    justify-content: space-between;
    margin-bottom: 4px;
  }
  .ic-tbl-fe__link {
    background: none;
    border: none;
    color: var(--ic-primary);
    cursor: pointer;
    font-size: 0.6rem;
    padding: 0;
  }
  .ic-tbl-fe__link:hover:not(:disabled) { text-decoration: underline; }
  .ic-tbl-fe__link:disabled {
    color: var(--ic-muted-foreground);
    cursor: default;
  }
  .ic-tbl-fe__list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    max-height: 150px;
    overflow-y: auto;
  }
  .ic-tbl-fe__item {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 3px 2px;
    border-radius: 2px;
    cursor: pointer;
    font-size: 0.7rem;
  }
  .ic-tbl-fe__item:hover {
    background: var(--ic-muted);
  }
  .ic-tbl-fe__cb {
    width: 12px;
    height: 12px;
    margin: 0;
    cursor: pointer;
    accent-color: var(--ic-primary);
    flex-shrink: 0;
  }
  .ic-tbl-fe__dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .ic-tbl-fe__dot--muted {
    background: var(--ic-muted-foreground);
    opacity: 0.4;
  }
  .ic-tbl-fe__label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--ic-foreground);
  }
</style>
