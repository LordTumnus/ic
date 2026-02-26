<script lang="ts">
  import type { FlatTreeRow, TreeTableNode } from '$lib/utils/tree-table-utils';
  import type { TableColumn } from '$lib/utils/table-utils';
  import { resolveAlign } from '$lib/utils/table-utils';
  import { resolveIcon } from '$lib/utils/icons';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import ContextMenu from '$lib/components/shared/ContextMenu.svelte';
  import TableCell from '../table/shared/TableCell.svelte';

  const INDENT_REM: Record<string, number> = { sm: 1, md: 1.25, lg: 1.5 };
  const FOLDER_SIZES: Record<string, number> = { sm: 12, md: 14, lg: 16 };
  const ICON_SIZES: Record<string, number> = { sm: 10, md: 12, lg: 14 };

  let {
    row,
    columns,
    columnWidths,
    expanderField,
    size = 'md',
    showLine = false,
    disabled = false,
    selectable = false,
    selected = false,
    atMaxSelections = false,
    striped = false,
    stripedIndex = 0,
    editingCell = null as { key: string; field: string } | null,
    ontoggleselect,
    ontoggleexpand,
    oncelldblclick,
    oncellclick,
    oncommitedit,
    oncanceledit,
    oncellaction,
    leafContextMenu = [] as ContextMenuEntry[],
    folderContextMenu = [] as ContextMenuEntry[],
    oncontextmenuaction,
  }: {
    row: FlatTreeRow;
    columns: TableColumn[];
    columnWidths: number[];
    expanderField: string;
    size?: string;
    showLine?: boolean;
    disabled?: boolean;
    selectable?: boolean;
    selected?: boolean;
    atMaxSelections?: boolean;
    striped?: boolean;
    stripedIndex?: number;
    editingCell?: { key: string; field: string } | null;
    ontoggleselect?: (key: string) => void;
    ontoggleexpand?: (key: string, expanded: boolean) => void;
    oncelldblclick?: (key: string, field: string) => void;
    oncellclick?: (key: string, field: string) => void;
    oncommitedit?: (key: string, field: string, oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
    oncellaction?: (key: string, field: string, data: unknown) => void;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    oncontextmenuaction?: (nodeKey: string, nodeType: 'leaf' | 'folder', itemKey: string, field?: string) => void;
  } = $props();

  const indent = $derived(INDENT_REM[size] ?? 1.25);

  // Folder icons
  const folderSvg = $derived(resolveIcon('folder', FOLDER_SIZES[size] ?? 14));
  const folderOpenSvg = $derived(resolveIcon('folder-open', FOLDER_SIZES[size] ?? 14));

  function getCellValue(node: TreeTableNode, field: string): unknown {
    if (field === expanderField) return node.name;
    return node.data?.[field] ?? null;
  }

  function handleFolderClick(e: MouseEvent) {
    e.stopPropagation();
    ontoggleexpand?.(row.key, !row.isExpanded);
  }

  function handleRowClick() {
    if (disabled) return;
    if (row.isFolder) {
      ontoggleexpand?.(row.key, !row.isExpanded);
    } else if (selectable) {
      if (atMaxSelections && !selected) return;
      ontoggleselect?.(row.key);
    }
  }

  function handleCellClick(field: string) {
    if (disabled) return;
    oncellclick?.(row.key, field);
  }

  function handleCellDblClick(field: string) {
    if (disabled) return;
    oncelldblclick?.(row.key, field);
  }

  function handleCommitEdit(field: string, oldValue: unknown, newValue: unknown) {
    oncommitedit?.(row.key, field, oldValue, newValue);
  }

  function handleCellAction(field: string, data: unknown) {
    oncellaction?.(row.key, field, data);
  }

  // --- Context menu ---
  let ctxMenu = $state<{ entries: ContextMenuEntry[]; x: number; y: number; field?: string } | null>(null);

  function handleFolderContextMenu(e: MouseEvent) {
    if (!folderContextMenu?.length) return;
    e.preventDefault();
    e.stopPropagation();
    ctxMenu = { entries: folderContextMenu, x: e.clientX, y: e.clientY };
  }

  function handleCellContextMenu(e: MouseEvent, col: TableColumn) {
    // Column-level menu takes priority
    if (col.contextMenu?.length) {
      e.preventDefault();
      e.stopPropagation();
      ctxMenu = { entries: col.contextMenu, x: e.clientX, y: e.clientY, field: col.field };
      return;
    }
    // Fall back to component-level leaf menu
    if (leafContextMenu?.length) {
      e.preventDefault();
      e.stopPropagation();
      ctxMenu = { entries: leafContextMenu, x: e.clientX, y: e.clientY };
    }
  }

  function handleCtxAction(key: string) {
    oncontextmenuaction?.(row.key, row.isFolder ? 'folder' : 'leaf', key, ctxMenu?.field);
    ctxMenu = null;
  }
</script>

{#if row.isFolder}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    class="ic-tt__row ic-tt__row--folder"
    class:ic-tt__row--expanded={row.isExpanded}
    class:ic-tt__row--disabled={disabled}
    class:ic-tt__row--selected={selected}
    role="row"
    tabindex={-1}
    onclick={handleRowClick}
    oncontextmenu={handleFolderContextMenu}
  >
    <div class="ic-tt__cell ic-tt__cell--folder">
      <!-- Guides -->
      {#if showLine}
        <span class="ic-tt__guides">
          {#each row.parentLines as showPipe, pi (pi)}
            <span
              class="ic-tt__guide"
              class:ic-tt__guide--pipe={showPipe}
              style:width="{indent}rem"
            ></span>
          {/each}
          <span
            class="ic-tt__guide ic-tt__guide--branch"
            class:ic-tt__guide--last={row.isLast}
            style:width="{indent}rem"
          ></span>
        </span>
      {:else}
        <span style="width: {row.depth * indent}rem; flex-shrink: 0"></span>
      {/if}

      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <span
        class="ic-tt__expand"
        role="button"
        tabindex={-1}
        onclick={handleFolderClick}
      >
        {@html row.isExpanded ? folderOpenSvg : folderSvg}
      </span>

      <!-- Node icon -->
      {#if row.node.icon}
        {@const svg = resolveIcon(row.node.icon, ICON_SIZES[size] ?? 12)}
        {#if svg}
          <span class="ic-tt__icon">{@html svg}</span>
        {/if}
      {/if}

      <!-- Label -->
      <span class="ic-tt__label ic-tt__label--folder">{row.node.name}</span>
    </div>
  </div>
{:else}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- ═══════ LEAF ROW (per-column cells) ═══════ -->
  <div
    class="ic-tt__row ic-tt__row--leaf"
    class:ic-tt__row--disabled={disabled || (selectable && atMaxSelections && !selected)}
    class:ic-tt__row--selected={selected}
    class:ic-tt__row--striped={striped && stripedIndex % 2 === 1}
    role="row"
    tabindex={-1}
    onclick={handleRowClick}
  >
    {#each columns as col, ci (col.field)}
      {@const w = columnWidths[ci]}
      {@const isExpander = col.field === expanderField}
      {@const isEditing = editingCell?.key === row.key && editingCell?.field === col.field}
      {@const cellValue = getCellValue(row.node, col.field)}
      {@const align = resolveAlign(col)}

      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <div
        class="ic-tt__cell"
        class:ic-tt__cell--left={align === 'left'}
        class:ic-tt__cell--center={align === 'center'}
        class:ic-tt__cell--right={align === 'right'}
        style:width="{w ? w + 'px' : 'auto'}"
        style:flex="{w ? '0 0 ' + w + 'px' : '1 1 0%'}"
        style:min-width="{col.minWidth || 40}px"
        role="gridcell"
        tabindex={-1}
        onclick={() => handleCellClick(col.field)}
        ondblclick={() => handleCellDblClick(col.field)}
        oncontextmenu={(e: MouseEvent) => handleCellContextMenu(e, col)}
      >
        {#if isExpander}
          <!-- Expander cell: guides + icon + label -->
          <div class="ic-tt__expander">
            {#if showLine}
              <span class="ic-tt__guides">
                {#each row.parentLines as showPipe, pi (pi)}
                  <span
                    class="ic-tt__guide"
                    class:ic-tt__guide--pipe={showPipe}
                    style:width="{indent}rem"
                  ></span>
                {/each}
                <span
                  class="ic-tt__guide ic-tt__guide--branch"
                  class:ic-tt__guide--last={row.isLast}
                  style:width="{indent}rem"
                ></span>
              </span>
            {:else}
              <span style="width: {row.depth * indent}rem; flex-shrink: 0"></span>
            {/if}

            <span
              class="ic-tt__content"
              class:ic-tt__content--selected={selectable && selected}
            >
              {#if row.node.icon}
                {@const svg = resolveIcon(row.node.icon, ICON_SIZES[size] ?? 12)}
                {#if svg}
                  <span class="ic-tt__icon">{@html svg}</span>
                {/if}
              {/if}
              <span class="ic-tt__label">{row.node.name}</span>
            </span>
          </div>
        {:else}
          <!-- Data cell: delegate to TableCell -->
          <TableCell
            column={col}
            value={cellValue}
            editing={isEditing}
            oncommitedit={(oldVal, newVal) => handleCommitEdit(col.field, oldVal, newVal)}
            oncanceledit={oncanceledit}
            oncellaction={(data) => handleCellAction(col.field, data)}
          />
        {/if}
      </div>
    {/each}
  </div>
{/if}

{#if ctxMenu}
  <ContextMenu entries={ctxMenu.entries} x={ctxMenu.x} y={ctxMenu.y}
      onaction={handleCtxAction} onclose={() => { ctxMenu = null; }} />
{/if}

<style>
  /* ═══════ ROW — matches TableRow.svelte .ic-tbl__row ═══════ */
  .ic-tt__row {
    display: flex;
    box-shadow: inset 0 -1px 0 var(--ic-border);
    transition: background-color 0.08s ease;
    user-select: none;
  }
  .ic-tt__row:last-child {
    box-shadow: none;
  }
  .ic-tt__row:hover {
    background: rgba(0, 0, 0, 0.03);
  }
  .ic-tt__row--striped {
    background: rgba(0, 0, 0, 0.02);
  }
  .ic-tt__row--striped:hover {
    background: rgba(0, 0, 0, 0.05);
  }
  .ic-tt__row--selected {
    background: rgba(59, 130, 246, 0.08);
  }
  .ic-tt__row--selected:hover {
    background: rgba(59, 130, 246, 0.12);
  }
  .ic-tt__row--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Folder row */
  .ic-tt__row--folder {
    cursor: pointer;
    font-weight: 500;
  }

  /* Leaf row */
  .ic-tt__row--leaf {
    cursor: pointer;
  }

  /* ═══════ CELLS — matches TableRow.svelte .ic-tbl__cell ═══════ */
  .ic-tt__cell {
    position: relative;
    display: flex;
    align-items: center;
    overflow: hidden;
    box-sizing: border-box;
    transition: background-color 0.08s ease;
  }
  .ic-tt__cell--left { justify-content: flex-start; }
  .ic-tt__cell--center { justify-content: center; }
  .ic-tt__cell--right { justify-content: flex-end; }

  /* Folder cell: spans full width */
  .ic-tt__cell--folder {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0 6px;
  }

  /* ═══════ EXPANDER (tree indent zone inside a leaf cell) ═══════ */
  .ic-tt__expander {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0 6px;
    min-width: 0;
    flex: 1;
  }

  /* ═══════ TREE GUIDES (reuse Tree pattern) ═══════ */
  .ic-tt__guides {
    display: flex;
    align-self: stretch;
    flex-shrink: 0;
    margin-top: -999px;
    margin-bottom: -999px;
    pointer-events: none;
  }
  .ic-tt__guide {
    position: relative;
    flex-shrink: 0;
    align-self: stretch;
  }
  /* Vertical pipe (│) */
  .ic-tt__guide--pipe::before {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }
  /* Branch connector (├ / └) — vertical */
  .ic-tt__guide--branch::before {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }
  /* Last child: vertical stops at center (└) */
  .ic-tt__guide--branch.ic-tt__guide--last::before {
    bottom: 50%;
  }
  /* Branch connector — horizontal */
  .ic-tt__guide--branch::after {
    content: '';
    position: absolute;
    left: 50%;
    top: 50%;
    right: -0.125rem;
    height: 1px;
    background: var(--ic-border);
  }

  /* ═══════ EXPAND ICON (folder toggle) ═══════ */
  .ic-tt__expand {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 16px;
    height: 16px;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    transition: color 0.1s ease;
  }
  .ic-tt__expand :global(svg) {
    fill: currentColor;
    fill-opacity: 0.15;
  }
  .ic-tt__expand:hover {
    color: var(--ic-foreground);
  }

  /* ═══════ CONTENT (icon + label in expander cell) ═══════ */
  .ic-tt__content {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    min-width: 0;
    border-radius: 2px;
    padding: 1px 0.25rem;
    margin: -1px -0.25rem;
    transition: background-color 0.12s ease, color 0.12s ease;
  }
  .ic-tt__content--selected {
    position: relative;
    color: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }
  .ic-tt__content--selected::before {
    content: '';
    position: absolute;
    inset: 0;
    background: var(--ic-primary);
    opacity: 0.13;
    border-radius: inherit;
    pointer-events: none;
  }

  /* ═══════ ICON & LABEL ═══════ */
  .ic-tt__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }
  .ic-tt__content--selected .ic-tt__icon {
    color: var(--ic-primary);
  }
  .ic-tt__label {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ic-tt__label--folder {
    font-weight: 500;
  }

  /* ═══════ TABLECELL WRAPPER ═══════
     TableCell provides its own padding (0 6px). Let it handle layout. */
  .ic-tt__cell > :global(.ic-tbl__cell) {
    flex: 1;
    min-width: 0;
  }
</style>
