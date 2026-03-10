import type { IconSource } from '$lib/utils/icons';

// --- Split tree ---

export type TileNode = TileSplit | TileLeaf;

export interface TileSplit {
	type: 'split';
	id: string;
	direction: 'horizontal' | 'vertical';
	/** First child's proportion, 0–1 */
	ratio: number;
	children: [TileNode, TileNode];
}

export interface TileLeaf {
	type: 'leaf';
	id: string;
	/** Tab target IDs in display order, e.g. ["tab-0", "tab-3"] */
	tabs: string[];
	/** Currently selected tab target */
	selectedTab: string;
}

// --- Drop zones ---

export type DropZone = 'center' | 'top' | 'bottom' | 'left' | 'right';

export interface DragState {
	active: boolean;
	/** Tab target being dragged */
	tabTarget: string;
	/** Group ID where drag originated */
	sourceGroupId: string;
	/** Current mouse position */
	mouseX: number;
	mouseY: number;
	/** Currently hovered group ID */
	hoveredGroupId: string | null;
	/** Active drop zone within hovered group */
	targetZone: DropZone | null;
}

// --- Tab config (read from ChildEntry proxy) ---

export interface TileTabConfig {
	label: string;
	icon: IconSource;
	closable: boolean;
	disabled: boolean;
}
