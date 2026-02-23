<script lang="ts">
  import type { TableColumn } from '$lib/utils/table-utils';
  import { resolveAlign } from '$lib/utils/table-utils';
  import TextCell from '../cells/text/TextCell.svelte';
  import NumberCell from '../cells/number/NumberCell.svelte';
  import BooleanCell from '../cells/boolean/BooleanCell.svelte';
  import ProgressBarCell from '../cells/progressbar/ProgressBarCell.svelte';
  import SparklineCell from '../cells/sparkline/SparklineCell.svelte';
  import ImageCell from '../cells/image/ImageCell.svelte';
  import EnumCell from '../cells/enum/EnumCell.svelte';

  let {
    column,
    value,
    oncellaction,
  }: {
    column: TableColumn;
    value: unknown;
    oncellaction?: (data: unknown) => void;
  } = $props();

  const align = $derived(resolveAlign(column));
  let cellStyle = $state('');
</script>

<div
  class="ic-tbl__cell"
  class:ic-tbl__cell--left={align === 'left'}
  class:ic-tbl__cell--center={align === 'center'}
  class:ic-tbl__cell--right={align === 'right'}
  style={cellStyle || null}
>
  {#if column.type === 'number'}
    <NumberCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'boolean'}
    <BooleanCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'progressbar'}
    <ProgressBarCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'sparkline'}
    <SparklineCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'image'}
    <ImageCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'enum'}
    <EnumCell {value} config={column.config} bind:style={cellStyle} />
  {:else}
    <TextCell {value} config={column.config} bind:style={cellStyle} />
  {/if}
</div>

<style>
  .ic-tbl__cell {
    display: flex;
    align-items: center;
    align-self: stretch;
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
