<script lang="ts">
  import type { BooleanConfig } from '$lib/utils/table-utils';
  import { evaluateColorRules } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<BooleanConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<BooleanConfig>;
    style?: string;
  } = $props();

  const checked = $derived(Boolean(value));
  const mode = $derived(config.displayMode ?? 'checkbox');
  const label = $derived(checked ? 'True' : 'False');
  const bgColor = $derived(
    config.colorRules?.length
      ? evaluateColorRules(checked ? 1 : 0, config.colorRules)
      : null
  );

  $effect(() => {
    style = bgColor
      ? `background-color: ${bgColor}; color: rgba(0,0,0,0.85);`
      : '';
  });

  let textEl = $state<HTMLSpanElement>(null!);
  let title = $state('');

  // Text/numeric: show on truncation. Checkbox: always show (visual-only).
  function onenter() {
    if (mode === 'checkbox' || textEl?.scrollWidth > textEl?.clientWidth) {
      title = label;
    }
  }
  function onleave() { title = ''; }
</script>

{#if mode === 'text'}
  <span
    bind:this={textEl}
    class="ic-tbl-cell-bool-text"
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >{label}</span>
{:else if mode === 'numeric'}
  <span
    bind:this={textEl}
    class="ic-tbl-cell-bool-text"
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >{checked ? '1' : '0'}</span>
{:else}
  <span
    bind:this={textEl}
    class="ic-tbl-cell-bool"
    class:ic-tbl-cell-bool--checked={checked}
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >
    {#if checked}
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M2.5 6L5 8.5L9.5 3.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    {/if}
  </span>
{/if}

<style>
  .ic-tbl-cell-bool {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    border-radius: 2px;
    background: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    color: var(--ic-primary-foreground);
    transition: all 0.1s ease;
  }
  .ic-tbl-cell-bool--checked {
    background: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.18);
  }
  .ic-tbl-cell-bool-text {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }
</style>
