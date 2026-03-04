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
  import RatingCell from '../cells/rating/RatingCell.svelte';
  import DateCell from '../cells/date/DateCell.svelte';
  import ButtonCell from '../cells/button/ButtonCell.svelte';
  import ColorCell from '../cells/color/ColorCell.svelte';

  let {
    column,
    value,
    editing = false,
    oncommitedit,
    oncanceledit,
    oncellaction,
  }: {
    column: TableColumn;
    value: unknown;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
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
    <NumberCell {value} config={column.config} bind:style={cellStyle}
      {editing} {oncommitedit} {oncanceledit} />
  {:else if column.type === 'boolean'}
    <BooleanCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'progressbar'}
    <ProgressBarCell {value} config={column.config} bind:style={cellStyle}
      {editing} {oncommitedit} {oncanceledit} />
  {:else if column.type === 'sparkline'}
    <SparklineCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'image'}
    <ImageCell {value} config={column.config} bind:style={cellStyle} />
  {:else if column.type === 'enum'}
    <EnumCell {value} config={column.config} bind:style={cellStyle}
      {editing} {oncommitedit} {oncanceledit} />
  {:else if column.type === 'rating'}
    <RatingCell {value} config={column.config} bind:style={cellStyle}
      {editing} {oncommitedit} {oncanceledit} />
  {:else if column.type === 'date'}
    <DateCell {value} config={column.config} bind:style={cellStyle}
      {editing} {oncommitedit} {oncanceledit} />
  {:else if column.type === 'button'}
    <ButtonCell {value} config={column.config} bind:style={cellStyle} {oncellaction} />
  {:else if column.type === 'color'}
    <ColorCell {value} config={column.config} bind:style={cellStyle}
      {editing} {oncommitedit} {oncanceledit} />
  {:else}
    <TextCell {value} config={column.config} bind:style={cellStyle}
      {editing} {oncommitedit} {oncanceledit} />
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
  .ic-tbl__cell--left { justify-content: flex-start; text-align: left; }
  .ic-tbl__cell--center { justify-content: center; text-align: center; }
  .ic-tbl__cell--right { justify-content: flex-end; text-align: right; }
</style>
