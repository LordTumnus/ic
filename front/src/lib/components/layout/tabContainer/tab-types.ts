import type { IconSource } from '$lib/utils/icons';

export interface TabConfig {
	label: string;
	closable: boolean;
	disabled: boolean;
	editable: boolean;
	icon: IconSource;
}

export interface TabContainerContext {
	registerTab(): string;
	updateTab(target: string, config: TabConfig): void;
	deregisterTab(target: string): void;
	renameTab(target: string, newLabel: string): void;
	get selectedTarget(): string;
	get containerDisabled(): boolean;
	get containerSize(): string;
	get lastRename(): { target: string; label: string } | null;
	closeTab(target: string): void;
}
