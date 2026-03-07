/**
 * TableControls — TipTap extension that shows "..." handles on the active
 * row and column when the cursor is inside a table. Clicking a handle opens
 * a dropdown menu with insert/delete options (Mac Notes-style).
 *
 * Uses the plugin's `update` lifecycle to manage DOM controls directly
 * on the `.tableWrapper` element.
 */
import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import type { EditorView } from '@tiptap/pm/view';
import type { Node as ProseMirrorNode } from '@tiptap/pm/model';
import { TableMap } from 'prosemirror-tables';
import { resolveIcon } from '$lib/utils/icons';

const TABLE_CONTROLS_KEY = new PluginKey('tableControls');

interface TableInfo {
  pos: number;
  node: ProseMirrorNode;
  depth: number;
}

/** Walk up from the selection head to find the enclosing table node. */
function findTableInSelection(state: any): TableInfo | null {
  const $head = state.selection.$head;
  for (let d = $head.depth; d > 0; d--) {
    const node = $head.node(d);
    if (node.type.name === 'table') {
      return { pos: $head.before(d), node, depth: d };
    }
  }
  return null;
}

/** Find the current cell's row/col indices within the table. */
function findCellRowCol(
  state: any,
  tableInfo: TableInfo,
): { row: number; col: number } | null {
  const map = TableMap.get(tableInfo.node);
  const $head = state.selection.$head;
  const tableStart = tableInfo.pos + 1;

  for (let d = $head.depth; d > 0; d--) {
    const node = $head.node(d);
    if (node.type.name === 'tableCell' || node.type.name === 'tableHeader') {
      const cellPos = $head.before(d) - tableStart;
      const rect = map.findCell(cellPos);
      return { row: rect.top, col: rect.left };
    }
  }
  return null;
}

// Pre-resolve icons once
const icEllipsis = resolveIcon('ellipsis', 14);
const icEllipsisV = resolveIcon('ellipsis-vertical', 14);
const icArrowUp = resolveIcon('arrow-up', 14);
const icArrowDown = resolveIcon('arrow-down', 14);
const icArrowLeft = resolveIcon('arrow-left', 14);
const icArrowRight = resolveIcon('arrow-right', 14);
const icTrash = resolveIcon('trash-2', 14);

type MenuAction = 'addRowBefore' | 'addRowAfter' | 'deleteRow'
  | 'addColumnBefore' | 'addColumnAfter' | 'deleteColumn';

interface MenuItem {
  label: string;
  icon: string;
  action: MenuAction;
  danger?: boolean;
}

const ROW_ITEMS: (MenuItem | 'sep')[] = [
  { label: 'Insert row above', icon: icArrowUp, action: 'addRowBefore' },
  { label: 'Insert row below', icon: icArrowDown, action: 'addRowAfter' },
  'sep',
  { label: 'Delete row', icon: icTrash, action: 'deleteRow', danger: true },
];

const COL_ITEMS: (MenuItem | 'sep')[] = [
  { label: 'Insert column left', icon: icArrowLeft, action: 'addColumnBefore' },
  { label: 'Insert column right', icon: icArrowRight, action: 'addColumnAfter' },
  'sep',
  { label: 'Delete column', icon: icTrash, action: 'deleteColumn', danger: true },
];

export const TableControls = Extension.create({
  name: 'tableControls',

  addProseMirrorPlugins() {
    const editor = this.editor;

    // ── Plugin-level state ──────────────────────────────────────────
    let currentWrapper: HTMLElement | null = null;
    let controlsContainer: HTMLElement | null = null;
    let rowHandle: HTMLButtonElement | null = null;
    let colHandle: HTMLButtonElement | null = null;
    let menuEl: HTMLElement | null = null;
    let activeRow = -1;
    let activeCol = -1;
    let activeTableInfo: TableInfo | null = null;

    // ── Menu helpers ────────────────────────────────────────────────
    function onClickOutside(e: MouseEvent) {
      if (menuEl && !menuEl.contains(e.target as Node)) {
        closeMenu();
      }
    }

    function closeMenu() {
      if (menuEl) {
        menuEl.remove();
        menuEl = null;
      }
      window.removeEventListener('mousedown', onClickOutside);
    }

    function executeCommand(action: MenuAction) {
      if (!activeTableInfo) return;
      const map = TableMap.get(activeTableInfo.node);

      // Pick a cell in the active row or column to anchor the command
      const isRowAction = action.includes('Row') || action.includes('row');
      const cellOffset = isRowAction
        ? map.map[activeRow * map.width]
        : map.map[activeCol];

      (editor.chain().focus()
        .setTextSelection(activeTableInfo.pos + cellOffset + 1) as any)
        [action]()
        .run();

      closeMenu();
    }

    function createMenu(type: 'row' | 'col'): HTMLDivElement {
      const menu = document.createElement('div');
      menu.className = 'ic-rte-tblmenu';

      const items = type === 'row' ? ROW_ITEMS : COL_ITEMS;
      for (const item of items) {
        if (item === 'sep') {
          const sep = document.createElement('div');
          sep.className = 'ic-rte-tblmenu__sep';
          menu.appendChild(sep);
          continue;
        }
        const btn = document.createElement('button');
        btn.className = 'ic-rte-tblmenu__item' + (item.danger ? ' ic-rte-tblmenu__item--danger' : '');
        btn.type = 'button';
        btn.innerHTML = `<span class="ic-rte-tblmenu__icon">${item.icon}</span>${item.label}`;
        btn.addEventListener('mousedown', (e) => {
          e.preventDefault();
          e.stopPropagation();
          executeCommand(item.action);
        });
        menu.appendChild(btn);
      }
      return menu;
    }

    function openMenu(handleEl: HTMLElement, type: 'row' | 'col') {
      closeMenu();
      menuEl = createMenu(type);
      document.body.appendChild(menuEl);

      // Position relative to the handle
      const rect = handleEl.getBoundingClientRect();
      const menuW = 180;
      const menuH = 120;
      const gap = 4;
      let x: number, y: number;

      if (type === 'row') {
        x = rect.right + gap;
        y = rect.top;
      } else {
        x = rect.left;
        y = rect.bottom + gap;
      }

      // Clamp to viewport
      if (x + menuW > window.innerWidth - gap) x = rect.left - menuW - gap;
      if (x < gap) x = gap;
      if (y + menuH > window.innerHeight - gap) y = rect.top - menuH - gap;
      if (y < gap) y = gap;

      menuEl.style.left = `${x}px`;
      menuEl.style.top = `${y}px`;

      setTimeout(() => window.addEventListener('mousedown', onClickOutside), 0);
    }

    // ── Controls lifecycle ──────────────────────────────────────────
    function cleanup() {
      if (controlsContainer?.parentElement) {
        controlsContainer.remove();
      }
      controlsContainer = null;
      rowHandle = null;
      colHandle = null;
      currentWrapper = null;
      activeRow = -1;
      activeCol = -1;
      activeTableInfo = null;
    }

    function buildControls(view: EditorView, tableInfo: TableInfo) {
      const tableDom = view.nodeDOM(tableInfo.pos);
      if (!tableDom) return;

      const wrapper =
        (tableDom as HTMLElement).classList?.contains('tableWrapper')
          ? (tableDom as HTMLElement)
          : (tableDom as HTMLElement).closest?.('.tableWrapper');
      if (!wrapper) return;

      const table = wrapper.querySelector('table');
      if (!table) return;

      const cellInfo = findCellRowCol(view.state, tableInfo);
      if (!cellInfo) { closeMenu(); cleanup(); return; }

      const { row, col } = cellInfo;

      // Same wrapper and same cell — no update needed
      if (
        wrapper === currentWrapper
        && controlsContainer?.parentElement === wrapper
        && activeRow === row
        && activeCol === col
      ) return;

      // Cell changed — close menu
      if (activeRow !== row || activeCol !== col) {
        closeMenu();
      }

      activeRow = row;
      activeCol = col;
      activeTableInfo = tableInfo;

      // Rebuild if wrapper changed
      const needsRebuild = wrapper !== currentWrapper || !controlsContainer?.parentElement;

      if (needsRebuild) {
        cleanup();
        activeRow = row;
        activeCol = col;
        activeTableInfo = tableInfo;
        currentWrapper = wrapper as HTMLElement;

        controlsContainer = document.createElement('div');
        controlsContainer.className = 'ic-rte-tblctrl';
        controlsContainer.contentEditable = 'false';

        rowHandle = document.createElement('button');
        rowHandle.className = 'ic-rte-tblctrl__handle ic-rte-tblctrl__handle--row';
        rowHandle.type = 'button';
        rowHandle.contentEditable = 'false';
        rowHandle.innerHTML = icEllipsisV;
        rowHandle.addEventListener('mousedown', (e) => {
          e.preventDefault();
          e.stopPropagation();
          openMenu(rowHandle!, 'row');
        });

        colHandle = document.createElement('button');
        colHandle.className = 'ic-rte-tblctrl__handle ic-rte-tblctrl__handle--col';
        colHandle.type = 'button';
        colHandle.contentEditable = 'false';
        colHandle.innerHTML = icEllipsis;
        colHandle.addEventListener('mousedown', (e) => {
          e.preventDefault();
          e.stopPropagation();
          openMenu(colHandle!, 'col');
        });

        controlsContainer.appendChild(rowHandle);
        controlsContainer.appendChild(colHandle);
        wrapper.appendChild(controlsContainer);
      }

      // Position handles after layout
      requestAnimationFrame(() => {
        if (!controlsContainer?.parentElement || !currentWrapper) return;
        const wrapperRect = currentWrapper.getBoundingClientRect();
        const rows = table.querySelectorAll('tr');

        // Row handle: center on active row
        if (rowHandle && rows[row]) {
          const trRect = rows[row].getBoundingClientRect();
          const handleH = 18;
          rowHandle.style.top = `${trRect.top - wrapperRect.top + (trRect.height - handleH) / 2}px`;
        }

        // Column handle: center on active column cell
        if (colHandle && rows.length > 0) {
          const cells = rows[0].querySelectorAll('th, td');
          let targetCell: Element | null = null;
          let colCounter = 0;
          for (const cell of cells) {
            const span = parseInt((cell as HTMLElement).getAttribute('colspan') ?? '1', 10);
            if (col >= colCounter && col < colCounter + span) {
              targetCell = cell;
              break;
            }
            colCounter += span;
          }
          if (targetCell) {
            const cellRect = targetCell.getBoundingClientRect();
            const handleW = 18;
            colHandle.style.left = `${cellRect.left - wrapperRect.left + (cellRect.width - handleW) / 2}px`;
          }
        }
      });
    }

    // ── Plugin ──────────────────────────────────────────────────────
    return [
      new Plugin({
        key: TABLE_CONTROLS_KEY,

        view() {
          return {
            update(view: EditorView) {
              const tableInfo = findTableInSelection(view.state);
              if (tableInfo) {
                buildControls(view, tableInfo);
              } else {
                closeMenu();
                cleanup();
              }
            },
            destroy() {
              closeMenu();
              cleanup();
            },
          };
        },
      }),
    ];
  },
});
