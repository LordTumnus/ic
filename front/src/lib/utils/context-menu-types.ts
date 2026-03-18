/**
 * Shared types for the reusable context menu system.
 * Used by Table, Tree, and any future component with right-click menus.
 */

/** A clickable leaf action. */
export interface ContextMenuItem {
  type: 'item';
  key: string;
  label?: string;
  icon?: string | { hash: string; mime?: string; data?: string };
  disabled?: boolean;
  shortcut?: string;
}

/** A visual divider line. */
export interface ContextMenuSeparator {
  type: 'separator';
}

/** A submenu container with nested entries. */
export interface ContextMenuFolder {
  type: 'folder';
  label?: string;
  icon?: string | { hash: string; mime?: string; data?: string };
  disabled?: boolean;
  children?: ContextMenuEntry[];
}

/** An inline color picker entry. */
export interface ContextMenuColorEntry {
  type: 'color';
  key: string;
  label?: string;
  value: string;
}

/** An inline text input entry. */
export interface ContextMenuTextEntry {
  type: 'text';
  key: string;
  label?: string;
  value: string;
  placeholder?: string;
}

/** An inline range slider entry. */
export interface ContextMenuRangeEntry {
  type: 'range';
  key: string;
  label?: string;
  value: number;
  min?: number;
  max?: number;
  step?: number;
}

/** Union of all context menu entry types. */
export type ContextMenuEntry = ContextMenuItem | ContextMenuSeparator | ContextMenuFolder | ContextMenuColorEntry | ContextMenuTextEntry | ContextMenuRangeEntry;
