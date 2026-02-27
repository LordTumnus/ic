<script lang="ts">
  import type { VttFlatRow, VirtualTreeTableNode } from '$lib/utils/virtual-tree-table';
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
    expandedKeys,
    loadingKeys,
    editingCell = null as { key: string; field: string } | null,
    leafContextMenu = [] as ContextMenuEntry[],
    folderContextMenu = [] as ContextMenuEntry[],
    ontoggleselect,
    ontoggleexpand,
    oncellclick,
    oncelldblclick,
    oncommitedit,
    oncanceledit,
    oncellaction,
    oncontextmenuaction,
  }: {
    row: VttFlatRow;
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
    expandedKeys: Set<string>;
    loadingKeys: Set<string>;
    editingCell?: { key: string; field: string } | null;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    ontoggleselect?: (key: string) => void;
    ontoggleexpand?: (key: string, expanded: boolean) => void;
    oncellclick?: (key: string, field: string) => void;
    oncelldblclick?: (key: string, field: string) => void;
    oncommitedit?: (key: string, field: string, oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
    oncellaction?: (key: string, field: string, data: unknown) => void;
    oncontextmenuaction?: (nodeKey: string, nodeType: 'leaf' | 'folder', itemKey: string, field?: string) => void;
  } = $props();

  const indent = $derived(INDENT_REM[size] ?? 1.25);
  const { node, depth, isLast, parentLines, isPlaceholder } = $derived(row);
  const isFolder = $derived(node.isFolder);
  const isExpanded = $derived(isFolder && expandedKeys.has(node.key));
  const isLoading = $derived(isFolder && loadingKeys.has(node.key));

  // Folder icons
  const folderSvg = $derived(resolveIcon('folder', FOLDER_SIZES[size] ?? 14));
  const folderOpenSvg = $derived(resolveIcon('folder-open', FOLDER_SIZES[size] ?? 14));

  function getCellValue(field: string): unknown {
    if (field === expanderField) return node.name;
    return (node as VirtualTreeTableNode).data?.[field] ?? null;
  }

  function handleFolderClick(e: MouseEvent) {
    e.stopPropagation();
    ontoggleexpand?.(node.key, !isExpanded);
  }

  function handleRowClick() {
    if (disabled) return;
    if (isFolder) {
      ontoggleexpand?.(node.key, !isExpanded);
    } else if (selectable) {
      if (atMaxSelections && !selected) return;
      ontoggleselect?.(node.key);
    }
  }

  function handleCellClick(field: string) {
    if (disabled) return;
    oncellclick?.(node.key, field);
  }

  function handleCellDblClick(field: string) {
    if (disabled) return;
    oncelldblclick?.(node.key, field);
  }

  function handleCommitEdit(field: string, oldValue: unknown, newValue: unknown) {
    oncommitedit?.(node.key, field, oldValue, newValue);
  }

  function handleCellAction(field: string, data: unknown) {
    oncellaction?.(node.key, field, data);
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
    if (col.contextMenu?.length) {
      e.preventDefault();
      e.stopPropagation();
      ctxMenu = { entries: col.contextMenu, x: e.clientX, y: e.clientY, field: col.field };
      return;
    }
    if (leafContextMenu?.length) {
      e.preventDefault();
      e.stopPropagation();
      ctxMenu = { entries: leafContextMenu, x: e.clientX, y: e.clientY };
    }
  }

  function handleCtxAction(key: string) {
    oncontextmenuaction?.(node.key, isFolder ? 'folder' : 'leaf', key, ctxMenu?.field);
    ctxMenu = null;
  }
</script>

{#if isPlaceholder}
  <!-- ═══════ PLACEHOLDER ROW (shimmer) ═══════ -->
  <div class="ic-tt__row ic-vtt__row--placeholder">
    {#if showLine}
      <span class="ic-tt__guides">
        {#each parentLines as showPipe, pi (pi)}
          <span
            class="ic-tt__guide"
            class:ic-tt__guide--pipe={showPipe}
            style:width="{indent}rem"
          ></span>
        {/each}
        <span
          class="ic-tt__guide ic-tt__guide--branch"
          class:ic-tt__guide--last={isLast}
          style:width="{indent}rem"
        ></span>
      </span>
    {:else}
      <span style="width: {depth * indent}rem; flex-shrink: 0"></span>
    {/if}
    <span class="ic-vtt__shimmer"></span>
  </div>
{:else if isFolder}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- ═══════ FOLDER ROW (full-width) ═══════ -->
  <div
    class="ic-tt__row ic-tt__row--folder"
    class:ic-tt__row--expanded={isExpanded}
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
          {#each parentLines as showPipe, pi (pi)}
            <span
              class="ic-tt__guide"
              class:ic-tt__guide--pipe={showPipe}
              style:width="{indent}rem"
            ></span>
          {/each}
          <span
            class="ic-tt__guide ic-tt__guide--branch"
            class:ic-tt__guide--last={isLast}
            style:width="{indent}rem"
          ></span>
        </span>
      {:else}
        <span style="width: {depth * indent}rem; flex-shrink: 0"></span>
      {/if}

      <!-- svelte-ignore a11y_click_events_have_key_events -->
      {#if isLoading}
        <span class="ic-tt__expand ic-vtt__spinner-wrap">
          <span class="ic-vtt__spinner" style:width="{FOLDER_SIZES[size] ?? 14}px" style:height="{FOLDER_SIZES[size] ?? 14}px"></span>
        </span>
      {:else}
        <span
          class="ic-tt__expand"
          role="button"
          tabindex={-1}
          onclick={handleFolderClick}
        >
          {@html isExpanded ? folderOpenSvg : folderSvg}
        </span>
      {/if}

      <!-- Node icon -->
      {#if node.icon}
        {@const svg = resolveIcon(node.icon, ICON_SIZES[size] ?? 12)}
        {#if svg}
          <span class="ic-tt__icon">{@html svg}</span>
        {/if}
      {/if}

      <!-- Label -->
      <span class="ic-tt__label ic-tt__label--folder">{node.name}</span>
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
      {@const isEditing = editingCell?.key === node.key && editingCell?.field === col.field}
      {@const cellValue = getCellValue(col.field)}
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
                {#each parentLines as showPipe, pi (pi)}
                  <span
                    class="ic-tt__guide"
                    class:ic-tt__guide--pipe={showPipe}
                    style:width="{indent}rem"
                  ></span>
                {/each}
                <span
                  class="ic-tt__guide ic-tt__guide--branch"
                  class:ic-tt__guide--last={isLast}
                  style:width="{indent}rem"
                ></span>
              </span>
            {:else}
              <span style="width: {depth * indent}rem; flex-shrink: 0"></span>
            {/if}

            <span
              class="ic-tt__content"
              class:ic-tt__content--selected={selectable && selected}
            >
              {#if node.icon}
                {@const svg = resolveIcon(node.icon, ICON_SIZES[size] ?? 12)}
                {#if svg}
                  <span class="ic-tt__icon">{@html svg}</span>
                {/if}
              {/if}
              <span class="ic-tt__label">{node.name}</span>
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
  /* ═══════ ROW — matches TreeTableRow.svelte ═══════ */
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

  .ic-tt__row--folder {
    cursor: pointer;
    font-weight: 500;
  }
  .ic-tt__row--leaf {
    cursor: pointer;
  }

  /* ═══════ PLACEHOLDER ROW ═══════ */
  .ic-vtt__row--placeholder {
    display: flex;
    align-items: center;
    opacity: 0.5;
  }

  .ic-vtt__shimmer {
    flex: 1;
    max-width: 40%;
    height: 8px;
    border-radius: 2px;
    background: var(--ic-secondary);
    opacity: 0.5;
  }

  /* ═══════ SPINNER (loading folder) ═══════ */
  .ic-vtt__spinner-wrap {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 16px;
    height: 16px;
  }

  .ic-vtt__spinner {
    border: 1.5px solid var(--ic-border);
    border-top-color: var(--ic-primary);
    border-radius: 50%;
    animation: ic-vtt-spin 0.6s linear infinite;
  }

  @keyframes ic-vtt-spin {
    to { transform: rotate(360deg); }
  }

  /* ═══════ CELLS — matches TreeTableRow.svelte ═══════ */
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

  .ic-tt__cell--folder {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0 6px;
  }

  /* ═══════ EXPANDER (tree indent zone in leaf cell) ═══════ */
  .ic-tt__expander {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0 6px;
    min-width: 0;
    flex: 1;
  }

  /* ═══════ TREE GUIDES ═══════ */
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
  .ic-tt__guide--pipe::before {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }
  .ic-tt__guide--branch::before {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }
  .ic-tt__guide--branch.ic-tt__guide--last::before {
    bottom: 50%;
  }
  .ic-tt__guide--branch::after {
    content: '';
    position: absolute;
    left: 50%;
    top: 50%;
    right: -0.125rem;
    height: 1px;
    background: var(--ic-border);
  }

  /* ═══════ EXPAND ICON ═══════ */
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

  /* ═══════ TABLECELL WRAPPER ═══════ */
  .ic-tt__cell > :global(.ic-tbl__cell) {
    flex: 1;
    min-width: 0;
  }
</style>
