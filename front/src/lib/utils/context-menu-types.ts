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

/** Union of all context menu entry types. */
export type ContextMenuEntry = ContextMenuItem | ContextMenuSeparator | ContextMenuFolder;
