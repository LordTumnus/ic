<script lang="ts">
  import type { DateConfig } from '$lib/utils/table-utils';
  import { formatDate, dateToEpoch } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<DateConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<DateConfig>;
    style?: string;
  } = $props();

  const format = $derived(config.format ?? 'short');
  const epoch = $derived(dateToEpoch(value));
  const hasValue = $derived(!isNaN(epoch));
  const display = $derived(hasValue ? formatDate(value, format) : '');

  // Tooltip: full ISO string for precision (e.g. when format is "short")
  const tooltip = $derived(hasValue ? new Date(epoch).toISOString() : '');

  let el = $state<HTMLSpanElement>(null!);
  let title = $state('');

  function onenter() {
    // Show tooltip if text is truncated OR always show full ISO for context
    title = tooltip;
  }
  function onleave() { title = ''; }

  $effect(() => { style = ''; });
</script>

{#if display}
  <span
    bind:this={el}
    class="ic-tbl-cell-date"
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >{display}</span>
{/if}

<style>
  .ic-tbl-cell-date {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
