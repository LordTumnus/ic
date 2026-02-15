<script lang="ts">
  import type { TableColumn, TableRow } from '$lib/utils/table-utils';
  import { resolveAlign } from '$lib/utils/table-utils';
  import TextCell from '../cells/TextCell.svelte';
  import NumberCell from '../cells/NumberCell.svelte';
  import BadgeCell from '../cells/BadgeCell.svelte';
  import SparklineCell from '../cells/SparklineCell.svelte';
  import ProgressCell from '../cells/ProgressCell.svelte';
  import BooleanCell from '../cells/BooleanCell.svelte';
  import ButtonCell from '../cells/ButtonCell.svelte';
  import LinkCell from '../cells/LinkCell.svelte';
  import IconCell from '../cells/IconCell.svelte';
  import AvatarCell from '../cells/AvatarCell.svelte';

  let {
    column,
    value,
    rowData = {},
    disabled = false,
    width = 150,
    onaction,
  }: {
    column: TableColumn;
    value: unknown;
    rowData?: TableRow;
    disabled?: boolean;
    width?: number;
    onaction?: () => void;
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
    <NumberCell {value} format={column.format} />
  {:else if column.type === 'badge'}
    <BadgeCell {value} config={column.config} />
  {:else if column.type === 'sparkline'}
    <SparklineCell {value} config={column.config} />
  {:else if column.type === 'progress'}
    <ProgressCell {value} config={column.config} />
  {:else if column.type === 'boolean'}
    <BooleanCell {value} />
  {:else if column.type === 'button'}
    <ButtonCell {value} config={column.config} {disabled} onclick={onaction} />
  {:else if column.type === 'link'}
    <LinkCell {value} onclick={onaction} />
  {:else if column.type === 'icon'}
    <IconCell {value} />
  {:else if column.type === 'avatar'}
    <AvatarCell {value} config={column.config} {rowData} />
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
  }
  .ic-tbl__cell--left { justify-content: flex-start; }
  .ic-tbl__cell--center { justify-content: center; }
  .ic-tbl__cell--right { justify-content: flex-end; }
</style>
