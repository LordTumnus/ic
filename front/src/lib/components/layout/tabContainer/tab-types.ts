import type { IconSource } from '$lib/utils/icons';

export interface TabConfig {
	label: string;
	closable: boolean;
	disabled: boolean;
	icon: IconSource;
}

export interface TabContainerContext {
	registerTab(): string;
	updateTab(target: string, config: TabConfig): void;
	deregisterTab(target: string): void;
	get selectedTarget(): string;
	get containerDisabled(): boolean;
	get containerSize(): string;
	closeTab(target: string): void;
}
