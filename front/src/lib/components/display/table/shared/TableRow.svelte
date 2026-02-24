<script lang="ts">
  import type { TableColumn, TableRow as TRow, PinnedInfo } from '$lib/utils/table-utils';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import { resolveAlign, isColumnEditable } from '$lib/utils/table-utils';
  import TableCell from './TableCell.svelte';
  import ContextMenu from '$lib/components/shared/ContextMenu.svelte';

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
    editingField = null as string | null,
    pinnedOffsets = new Map() as Map<string, PinnedInfo>,
    stickingFields = new Set<string>(),
    onclick,
    oncellclick,
    oncellaction,
    oncontextmenuaction,
    onrownumclick,
    onstartedit,
    oncommitedit,
    oncanceledit,
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
    editingField?: string | null;
    pinnedOffsets?: Map<string, PinnedInfo>;
    stickingFields?: Set<string>;
    onclick?: (rowIndex: number, rowData: TRow) => void;
    oncellclick?: (field: string, rowIndex: number, value: unknown, rowData: TRow, shiftKey: boolean) => void;
    oncellaction?: (field: string, rowIndex: number, data: unknown) => void;
    oncontextmenuaction?: (field: string, rowIndex: number, itemKey: string) => void;
    onrownumclick?: (rowIndex: number, shiftKey: boolean) => void;
    onstartedit?: (field: string, rowIndex: number) => void;
    oncommitedit?: (field: string, rowIndex: number, oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
  } = $props();

  function handleRowClick(e: MouseEvent) {
    // Cell/rownum clicks are handled separately — skip if click originated there
    // (Svelte 5 event delegation may bypass stopPropagation between parent-child)
    const target = e.target as HTMLElement;
    if (target !== e.currentTarget && target.closest('.ic-tbl__cell')) return;
    onclick?.(rowIndex, rowData);
  }

  function handleCellClick(e: MouseEvent, field: string) {
    e.stopPropagation();
    oncellclick?.(field, rowIndex, rowData[field], rowData, e.shiftKey);
  }

  /** Prevent native text selection on shift+click and double-click. */
  function handleMouseDown(e: MouseEvent) {
    if (e.shiftKey || e.detail === 2) e.preventDefault();
  }

  function handleCellDblClick(e: MouseEvent, field: string) {
    e.stopPropagation();
    e.preventDefault();           // prevent native word-select on double-click
    const col = columns.find(c => c.field === field);
    // Boolean toggles on single click, not double-click
    if (col?.type === 'boolean') return;
    onstartedit?.(field, rowIndex);
  }

  function handleRowNumClick(e: MouseEvent) {
    e.stopPropagation();
    onrownumclick?.(rowIndex, e.shiftKey);
  }

  // ── Context Menu ────────────────────────────────────
  let ctxMenu = $state<{ entries: ContextMenuEntry[]; x: number; y: number; field: string } | null>(null);

  function handleContextMenu(e: MouseEvent, col: TableColumn) {
    if (!col.contextMenu?.length) return;
    e.preventDefault();
    e.stopPropagation();
    ctxMenu = { entries: col.contextMenu, x: e.clientX, y: e.clientY, field: col.field };
  }

  function handleCtxAction(key: string) {
    if (ctxMenu) oncontextmenuaction?.(ctxMenu.field, rowIndex, key);
    ctxMenu = null;
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
      case 'Enter': {
        e.preventDefault();
        const enterCol = columns.find(c => c.field === field);
        if (enterCol && isColumnEditable(enterCol) && enterCol.type !== 'boolean' && !editingField) {
          onstartedit?.(field, rowIndex);
        } else {
          oncellclick?.(field, rowIndex, rowData[field], rowData, e.shiftKey);
        }
        break;
      }
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
      onmousedown={handleMouseDown}
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
      onmousedown={handleMouseDown}
      onclick={(e: MouseEvent) => handleCellClick(e, col.field)}
      ondblclick={(e: MouseEvent) => handleCellDblClick(e, col.field)}
      oncontextmenu={(e: MouseEvent) => handleContextMenu(e, col)}
      onkeydown={(e: KeyboardEvent) => handleCellKeydown(e, col.field)}
      role="gridcell"
      tabindex={-1}
    >
      <TableCell
        column={col}
        value={rowData[col.field]}
        editing={editingField === col.field}
        oncommitedit={(oldVal: unknown, newVal: unknown) =>
          oncommitedit?.(col.field, rowIndex, oldVal, newVal)}
        {oncanceledit}
        oncellaction={col.hasAction
          ? (data: unknown) => oncellaction?.(col.field, rowIndex, data)
          : undefined}
      />
    </div>
  {/each}

  {#if ctxMenu}
    <ContextMenu
      entries={ctxMenu.entries}
      x={ctxMenu.x}
      y={ctxMenu.y}
      onaction={handleCtxAction}
      onclose={() => { ctxMenu = null; }}
    />
  {/if}
</div>

<style>
  .ic-tbl__row {
    --_row-tint: transparent;
    display: flex;
    box-shadow: inset 0 -1px 0 var(--ic-border);
    transition: background-color 0.08s ease;
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
    color: var(--ic-primary-foreground);
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.15);
  }

  /* Data cells — no border so cell-renderer backgrounds fill edge-to-edge;
     focus/active use outline (no layout impact). */
  .ic-tbl__cell {
    position: relative;
    display: flex;
    align-items: center;
    overflow: hidden;
    box-sizing: border-box;
    transition: background-color 0.08s ease;
  }
  .ic-tbl__cell:focus {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
  }
  .ic-tbl__cell--rownum:focus {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
    box-shadow: inset 0 0 0 1px var(--ic-primary);
  }
  .ic-tbl__cell--left { justify-content: flex-start; }
  .ic-tbl__cell--center { justify-content: center; }
  .ic-tbl__cell--right { justify-content: flex-end; }

  /* Active cell — the specifically clicked cell */
  .ic-tbl__cell--active {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
    background: rgba(59, 130, 246, 0.06);
  }
  /* Pinned + active — layer active tint over opaque pinned background */
  .ic-tbl__cell--pinned.ic-tbl__cell--active {
    background:
      linear-gradient(rgba(59, 130, 246, 0.06), rgba(59, 130, 246, 0.06)),
      linear-gradient(var(--_row-tint), var(--_row-tint)),
      var(--ic-background);
  }

  /* Pinned cell — always opaque so scrolling content doesn't bleed through.
     Reads --_row-tint (inherited from parent row) so hover/striped/selected
     tints apply automatically without parent > child selectors.
     Bottom separator via inset box-shadow (no border). */
  .ic-tbl__cell--pinned {
    background: linear-gradient(var(--_row-tint), var(--_row-tint)), var(--ic-background);
    box-shadow: inset 0 -1px 0 var(--ic-border);
  }
  .ic-tbl__row:last-child > .ic-tbl__cell--pinned {
    box-shadow: none;
  }
  /* Sticking — directional shadow + bottom separator */
  .ic-tbl__cell--sticking {
    box-shadow: 2px 0 4px rgba(0, 0, 0, 0.06), inset 0 -1px 0 var(--ic-border);
  }
  .ic-tbl__cell--sticking.ic-tbl__cell--pinned-right {
    box-shadow: -2px 0 4px rgba(0, 0, 0, 0.06), inset 0 -1px 0 var(--ic-border);
  }
  .ic-tbl__row:last-child > .ic-tbl__cell--sticking {
    box-shadow: 2px 0 4px rgba(0, 0, 0, 0.06);
  }
  .ic-tbl__row:last-child > .ic-tbl__cell--sticking.ic-tbl__cell--pinned-right {
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
