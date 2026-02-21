<script lang="ts">
  import type { TableColumn } from '$lib/utils/table-utils';
  import { resolveAlign } from '$lib/utils/table-utils';
  import TextCell from '../cells/TextCell.svelte';
  import NumberCell from '../cells/NumberCell.svelte';
  import BooleanCell from '../cells/BooleanCell.svelte';

  let {
    column,
    value,
  }: {
    column: TableColumn;
    value: unknown;
  } = $props();

  const align = $derived(resolveAlign(column));
</script>

<div
  class="ic-tbl__cell"
  class:ic-tbl__cell--left={align === 'left'}
  class:ic-tbl__cell--center={align === 'center'}
  class:ic-tbl__cell--right={align === 'right'}
>
  {#if column.type === 'number'}
    <NumberCell {value} />
  {:else if column.type === 'boolean'}
    <BooleanCell {value} />
  {:else}
    <TextCell {value} />
  {/if}
</div>

<style>
  .ic-tbl__cell {
    display: flex;
    align-items: center;
    padding: 0 6px;
    overflow: hidden;
    box-sizing: border-box;
    flex: 1;
    min-width: 0;
  }
  .ic-tbl__cell--left { justify-content: flex-start; }
  .ic-tbl__cell--center { justify-content: center; }
  .ic-tbl__cell--right { justify-content: flex-end; }
</style>
