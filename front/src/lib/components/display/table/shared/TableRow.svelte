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

  // ── DOM Navigation Helpers ────────────────────────────
  // All navigation is DOM-based: find sibling rows/cells via querySelector
  // so we don't need to track focus position in state.

  /** Get the row number cell in a sibling row (up/down from current row). */
  function getSiblingRowNum(direction: -1 | 1): HTMLElement | null {
    const row = (document.activeElement as HTMLElement)?.closest('.ic-tbl__row');
    if (!row) return null;
    const sibling = direction === -1 ? row.previousElementSibling : row.nextElementSibling;
    return sibling?.querySelector('.ic-tbl__cell--rownum') as HTMLElement | null;
  }

  /** Selector for direct-child data cells (excludes the inner .ic-tbl__cell
   *  rendered by TableCell.svelte which shares the same class name). */
  const DATA_CELL_SEL = ':scope > .ic-tbl__cell:not(.ic-tbl__cell--rownum)';

  /** Get a data cell at a given column index in a target row element. */
  function getDataCellAt(row: Element, colIdx: number): HTMLElement | null {
    const cells = row.querySelectorAll<HTMLElement>(DATA_CELL_SEL);
    return cells[colIdx] ?? null;
  }

  /** Get the column index of the currently focused data cell within its row. */
  function getCurrentColIndex(cell: HTMLElement): number {
    const row = cell.closest('.ic-tbl__row');
    if (!row) return -1;
    const cells = [...row.querySelectorAll<HTMLElement>(DATA_CELL_SEL)];
    return cells.indexOf(cell);
  }

  // ── Row Number Keydown ────────────────────────────────
  function handleRowNumKeydown(e: KeyboardEvent) {
    switch (e.key) {
      case 'ArrowUp': {
        e.preventDefault();
        const target = getSiblingRowNum(-1);
        if (target) {
          target.focus();
        } else {
          // At first row — move to header row-number cell
          const header = (e.currentTarget as HTMLElement).closest('.ic-tbl')
            ?.querySelector('.ic-tbl__hcell--rownum') as HTMLElement | null;
          header?.focus();
        }
        break;
      }
      case 'ArrowDown': {
        e.preventDefault();
        getSiblingRowNum(1)?.focus();
        break;
      }
      case 'ArrowRight': {
        e.preventDefault();
        const row = (e.currentTarget as HTMLElement).closest('.ic-tbl__row');
        if (row) getDataCellAt(row, 0)?.focus();
        break;
      }
      case 'Enter':
        e.preventDefault();
        onrownumclick?.(rowIndex, e.shiftKey);
        break;
    }
  }

  // ── Data Cell Keydown ─────────────────────────────────
  function handleCellKeydown(e: KeyboardEvent, field: string) {
    const cell = e.currentTarget as HTMLElement;
    const row = cell.closest('.ic-tbl__row');
    if (!row) return;
    const colIdx = getCurrentColIndex(cell);

    switch (e.key) {
      case 'ArrowLeft': {
        e.preventDefault();
        if (colIdx > 0) {
          getDataCellAt(row, colIdx - 1)?.focus();
        } else if (showRowNumber) {
          const rn = row.querySelector('.ic-tbl__cell--rownum') as HTMLElement | null;
          rn?.focus();
        }
        break;
      }
      case 'ArrowRight': {
        e.preventDefault();
        getDataCellAt(row, colIdx + 1)?.focus();
        break;
      }
      case 'ArrowUp': {
        e.preventDefault();
        const siblingRow = row.previousElementSibling;
        if (siblingRow?.classList.contains('ic-tbl__row')) {
          getDataCellAt(siblingRow, colIdx)?.focus();
        } else {
          const table = row.closest('.ic-tbl');
          const headers = table?.querySelectorAll<HTMLElement>('.ic-tbl__hcell:not(.ic-tbl__hcell--rownum)');
          headers?.[colIdx]?.focus();
        }
        break;
      }
      case 'ArrowDown': {
        e.preventDefault();
        const nextRow = row.nextElementSibling;
        if (nextRow?.classList.contains('ic-tbl__row')) {
          getDataCellAt(nextRow, colIdx)?.focus();
        }
        break;
      }
      case 'Enter':
        e.preventDefault();
        oncellclick?.(field, rowIndex, rowData[field], rowData, e.shiftKey);
        break;
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<div
  class="ic-tbl__row"
  class:ic-tbl__row--selected={selected}
  class:ic-tbl__row--striped={striped && even}
  class:ic-tbl__row--disabled={disabled}
  onclick={handleRowClick}
  role="row"
  tabindex={-1}
>
  {#if showRowNumber}
    <div
      class="ic-tbl__cell ic-tbl__cell--rownum"
      class:ic-tbl__cell--sticking={stickingFields.has('__rownum__')}
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
      tabindex={-1}
    >
      {rowIndex + 1}
    </div>
  {/if}

  {#each columns as col, i (i)}
    {@const isCellActive = activeCells.some(c => c.field === col.field && c.rowIndex === rowIndex)}
    {@const isColActive = activeColumns.includes(col.field)}
    {@const align = resolveAlign(col)}
    {@const pinInfo = pinnedOffsets.get(col.field)}
    <div
      class="ic-tbl__cell"
      class:ic-tbl__cell--active={isCellActive}
      class:ic-tbl__cell--col-active={isColActive}
      class:ic-tbl__cell--pinned={pinInfo != null}
      class:ic-tbl__cell--pinned-right={pinInfo?.side === 'right'}
      class:ic-tbl__cell--sticking={pinInfo != null && stickingFields.has(col.field)}
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
      onkeydown={(e: KeyboardEvent) => handleCellKeydown(e, col.field)}
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
    --_row-tint: transparent;
    display: flex;
    box-shadow: inset 0 -1px 0 var(--ic-border);
    transition: background-color 0.08s ease;
    user-select: none;
  }
  .ic-tbl__row:last-child {
    box-shadow: none;
  }
  .ic-tbl__row:hover {
    --_row-tint: rgba(0, 0, 0, 0.03);
    background: rgba(0, 0, 0, 0.03);
  }
  .ic-tbl__row--striped {
    --_row-tint: rgba(0, 0, 0, 0.02);
    background: rgba(0, 0, 0, 0.02);
  }
  .ic-tbl__row--striped:hover {
    --_row-tint: rgba(0, 0, 0, 0.05);
    background: rgba(0, 0, 0, 0.05);
  }
  .ic-tbl__row--selected {
    --_row-tint: rgba(59, 130, 246, 0.08);
    background: rgba(59, 130, 246, 0.08);
  }
  .ic-tbl__row--selected:hover {
    --_row-tint: rgba(59, 130, 246, 0.12);
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
    position: relative;
    display: flex;
    align-items: center;
    overflow: hidden;
    box-sizing: border-box;
    border: 1px solid transparent;
    transition: border-color 0.08s ease, background-color 0.08s ease;
  }
  .ic-tbl__cell:focus {
    outline: none;
    border-color: var(--ic-primary);
  }
  .ic-tbl__cell--rownum:focus {
    outline: none;
    border-color: var(--ic-primary);
    box-shadow: inset 0 0 0 1px var(--ic-primary);
  }
  .ic-tbl__cell--left { justify-content: flex-start; }
  .ic-tbl__cell--center { justify-content: center; }
  .ic-tbl__cell--right { justify-content: flex-end; }

  /* Active cell — the specifically clicked cell */
  .ic-tbl__cell--active {
    border-color: var(--ic-primary);
    background: rgba(59, 130, 246, 0.06);
  }

  /* Pinned cell — always opaque so scrolling content doesn't bleed through.
     Reads --_row-tint (inherited from parent row) so hover/striped/selected
     tints apply automatically without parent > child selectors. */
  .ic-tbl__cell--pinned {
    background: linear-gradient(var(--_row-tint), var(--_row-tint)), var(--ic-background);
    border-bottom-color: var(--ic-border);
  }
  .ic-tbl__row:last-child > .ic-tbl__cell--pinned {
    border-bottom-color: transparent;
  }
  /* Sticking — directional shadow when sticky position is active */
  .ic-tbl__cell--sticking {
    box-shadow: 2px 0 4px rgba(0, 0, 0, 0.06);
  }
  .ic-tbl__cell--sticking.ic-tbl__cell--pinned-right {
    box-shadow: -2px 0 4px rgba(0, 0, 0, 0.06);
  }

  /* Column highlight — ::after overlay avoids specificity conflicts with
     row-state tints (striped, hover, selected) on pinned cells */
  .ic-tbl__cell--col-active::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(59, 130, 246, 0.08);
    pointer-events: none;
  }
</style>
