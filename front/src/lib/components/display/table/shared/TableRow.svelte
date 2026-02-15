<script lang="ts">
  import type { TableColumn, TableRow as TRow, PinnedInfo } from '$lib/utils/table-utils';
  import { resolveAlign } from '$lib/utils/table-utils';
  import TableCell from './TableCell.svelte';

  let {
    columns,
    columnWidths,
    rowData,
    rowIndex,
    selected = false,
    disabled = false,
    selectable = false,
    showRowNumber = false,
    rowNumWidth = 24,
    striped = false,
    even = false,
    activeColumns = [] as string[],
    activeCells = [] as { field: string; rowIndex: number }[],
    pinnedOffsets = new Map() as Map<string, PinnedInfo>,
    stickingFields = new Set<string>(),
    onclick,
    oncellclick,
    oncellaction,
    onrownumclick,
  }: {
    columns: TableColumn[];
    columnWidths: number[];
    rowData: TRow;
    rowIndex: number;
    selected?: boolean;
    disabled?: boolean;
    selectable?: boolean;
    showRowNumber?: boolean;
    rowNumWidth?: number;
    striped?: boolean;
    even?: boolean;
    activeColumns?: string[];
    activeCells?: { field: string; rowIndex: number }[];
    pinnedOffsets?: Map<string, PinnedInfo>;
    stickingFields?: Set<string>;
    onclick?: (rowIndex: number, rowData: TRow) => void;
    oncellclick?: (field: string, rowIndex: number, value: unknown, rowData: TRow, shiftKey: boolean) => void;
    oncellaction?: (field: string, rowIndex: number, value: unknown, rowData: TRow) => void;
    onrownumclick?: (rowIndex: number, shiftKey: boolean) => void;
  } = $props();

  function handleRowClick() {
    onclick?.(rowIndex, rowData);
  }

  function handleCellClick(e: MouseEvent, field: string) {
    e.stopPropagation();
    oncellclick?.(field, rowIndex, rowData[field], rowData, e.shiftKey);
  }

  function handleRowNumClick(e: MouseEvent) {
    e.stopPropagation();
    onrownumclick?.(rowIndex, e.shiftKey);
  }

  function handleRowNumKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      e.stopPropagation();
      onrownumclick?.(rowIndex, e.shiftKey);
    }
  }
</script>

<div
  class="ic-tbl__row"
  class:ic-tbl__row--selected={selected}
  class:ic-tbl__row--striped={striped && even}
  class:ic-tbl__row--disabled={disabled}
  onclick={handleRowClick}
  onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); handleRowClick(); } }}
  role="row"
  tabindex={0}
>
  {#if showRowNumber}
    <div
      class="ic-tbl__cell ic-tbl__cell--rownum"
      class:ic-tbl__cell--pinned={stickingFields.has('__rownum__')}
      class:ic-tbl__cell--rownum-selected={selected}
      class:ic-tbl__cell--rownum-selectable={selectable}
      style:flex="0 0 {rowNumWidth}px"
      style:width="{rowNumWidth}px"
      style:position="sticky"
      style:left="0px"
      style:z-index={1}
      onclick={handleRowNumClick}
      onkeydown={handleRowNumKeydown}
      role="rowheader"
      tabindex={selectable ? 0 : -1}
    >
      {rowIndex + 1}
    </div>
  {/if}

  {#each columns as col, i (col.field)}
    {@const isCellActive = activeCells.some(c => c.field === col.field && c.rowIndex === rowIndex)}
    {@const isColActive = activeColumns.includes(col.field)}
    {@const align = resolveAlign(col)}
    {@const pinInfo = pinnedOffsets.get(col.field)}
    <div
      class="ic-tbl__cell"
      class:ic-tbl__cell--active={isCellActive}
      class:ic-tbl__cell--col-active={isColActive}
      class:ic-tbl__cell--pinned={pinInfo != null && stickingFields.has(col.field)}
      class:ic-tbl__cell--pinned-right={pinInfo?.side === 'right' && stickingFields.has(col.field)}
      class:ic-tbl__cell--left={align === 'left'}
      class:ic-tbl__cell--center={align === 'center'}
      class:ic-tbl__cell--right={align === 'right'}
      style:width="{columnWidths[i] ? columnWidths[i] + 'px' : 'auto'}"
      style:flex="{columnWidths[i] ? '0 0 ' + columnWidths[i] + 'px' : '1 1 0%'}"
      style:min-width="{col.minWidth || 40}px"
      style:position={pinInfo ? 'sticky' : undefined}
      style:left={pinInfo?.side === 'left' ? pinInfo.offset + 'px' : undefined}
      style:right={pinInfo?.side === 'right' ? pinInfo.offset + 'px' : undefined}
      style:z-index={pinInfo ? 1 : undefined}
      onclick={(e: MouseEvent) => handleCellClick(e, col.field)}
      onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') { oncellclick?.(col.field, rowIndex, rowData[col.field], rowData, e.shiftKey); } }}
      role="gridcell"
      tabindex={-1}
    >
      <TableCell
        column={col}
        value={rowData[col.field]}
        {rowData}
        {disabled}
        width={columnWidths[i] || 0}
        onaction={() => oncellaction?.(col.field, rowIndex, rowData[col.field], rowData)}
      />
    </div>
  {/each}
</div>

<style>
  .ic-tbl__row {
    display: flex;
    box-shadow: inset 0 -1px 0 var(--ic-border);
    transition: background-color 0.08s ease;
    user-select: none;
  }
  .ic-tbl__row:last-child {
    box-shadow: none;
  }
  .ic-tbl__row:hover {
    background: rgba(0, 0, 0, 0.03);
  }
  .ic-tbl__row--striped {
    background: rgba(0, 0, 0, 0.02);
  }
  .ic-tbl__row--striped:hover {
    background: rgba(0, 0, 0, 0.05);
  }
  .ic-tbl__row--selected {
    background: rgba(59, 130, 246, 0.08);
  }
  .ic-tbl__row--selected:hover {
    background: rgba(59, 130, 246, 0.12);
  }
  .ic-tbl__row--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Row number gutter — deep recessed channel */
  .ic-tbl__cell--rownum {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 2px;
    color: var(--ic-foreground);
    opacity: 0.7;
    font-variant-numeric: tabular-nums;
    font-size: 0.7em;
    font-weight: 500;
    background: var(--ic-secondary);
    border-right: 2px solid var(--ic-border);
    box-shadow: inset -3px 0 6px rgba(0, 0, 0, 0.08);
    user-select: none;
    transition: background-color 0.08s ease, color 0.08s ease, opacity 0.08s ease;
  }
  /* On row hover, lighten the gutter so the whole row feels highlighted */
  .ic-tbl__row:hover > .ic-tbl__cell--rownum:not(.ic-tbl__cell--rownum-selected) {
    background: var(--ic-secondary);
    box-shadow: inset -1px 0 2px rgba(0, 0, 0, 0.04);
  }
  .ic-tbl__cell--rownum-selectable {
    cursor: pointer;
  }
  .ic-tbl__cell--rownum-selectable:hover {
    color: var(--ic-foreground);
    opacity: 1;
  }
  .ic-tbl__cell--rownum-selected {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    opacity: 1;
    border-radius: 0;
    box-shadow: none;
  }
  .ic-tbl__cell--rownum-selected:hover {
    background: var(--ic-primary);
  }

  /* Data cells */
  .ic-tbl__cell {
    display: flex;
    align-items: center;
    overflow: hidden;
    box-sizing: border-box;
    border: 1px solid transparent;
    transition: border-color 0.08s ease, background-color 0.08s ease;
  }
  .ic-tbl__cell--left { justify-content: flex-start; }
  .ic-tbl__cell--center { justify-content: center; }
  .ic-tbl__cell--right { justify-content: flex-end; }

  /* Active cell — the specifically clicked cell */
  .ic-tbl__cell--active {
    border-color: var(--ic-primary);
    background: rgba(59, 130, 246, 0.06);
  }

  /* Pinned cell — opaque so scrolling content doesn't bleed through.
     Row state tints are layered via linear-gradient over the opaque base
     (can't use rgba alone — it would be semi-transparent and bleed). */
  .ic-tbl__cell--pinned {
    background: var(--ic-background);
    box-shadow: 2px 0 4px rgba(0, 0, 0, 0.06);
  }
  .ic-tbl__cell--pinned-right {
    box-shadow: -2px 0 4px rgba(0, 0, 0, 0.06);
  }
  .ic-tbl__cell--pinned.ic-tbl__cell--rownum-selected {
    background: var(--ic-primary);
  }
  .ic-tbl__row:hover > .ic-tbl__cell--pinned:not(.ic-tbl__cell--rownum) {
    background: linear-gradient(rgba(0, 0, 0, 0.03), rgba(0, 0, 0, 0.03)), var(--ic-background);
  }
  .ic-tbl__row--striped > .ic-tbl__cell--pinned:not(.ic-tbl__cell--rownum) {
    background: linear-gradient(rgba(0, 0, 0, 0.02), rgba(0, 0, 0, 0.02)), var(--ic-background);
  }
  .ic-tbl__row--striped:hover > .ic-tbl__cell--pinned:not(.ic-tbl__cell--rownum) {
    background: linear-gradient(rgba(0, 0, 0, 0.05), rgba(0, 0, 0, 0.05)), var(--ic-background);
  }
  .ic-tbl__row--selected > .ic-tbl__cell--pinned:not(.ic-tbl__cell--rownum) {
    background: linear-gradient(rgba(59, 130, 246, 0.08), rgba(59, 130, 246, 0.08)), var(--ic-background);
  }
  .ic-tbl__row--selected:hover > .ic-tbl__cell--pinned:not(.ic-tbl__cell--rownum) {
    background: linear-gradient(rgba(59, 130, 246, 0.12), rgba(59, 130, 246, 0.12)), var(--ic-background);
  }

  /* Column highlight — all cells in the selected column */
  .ic-tbl__cell--col-active {
    background: rgba(59, 130, 246, 0.04);
  }
  .ic-tbl__cell--pinned.ic-tbl__cell--col-active {
    background: linear-gradient(rgba(59, 130, 246, 0.04), rgba(59, 130, 246, 0.04)), var(--ic-background);
  }
  .ic-tbl__cell--pinned.ic-tbl__cell--active {
    background: linear-gradient(rgba(59, 130, 246, 0.06), rgba(59, 130, 246, 0.06)), var(--ic-background);
  }
</style>
