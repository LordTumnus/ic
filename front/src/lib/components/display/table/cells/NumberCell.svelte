<script lang="ts">
  import { formatNumber } from '$lib/utils/table-utils';

  let { value, format = '' }: { value?: unknown; format?: string } = $props();

  const display = $derived(
    value != null ? formatNumber(Number(value), format) : ''
  );
</script>

<span class="ic-tbl-cell-number">{display}</span>

<style>
  .ic-tbl-cell-number {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }
</style>
