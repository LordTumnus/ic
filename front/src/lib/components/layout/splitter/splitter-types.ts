export interface PaneConfig {
	size: number | null;
	minSize: number;
	maxSize: number;
	snapSize: number;
}

export interface PaneHandle {
	setSize: (v: number) => void;
}

export interface SplitterContext {
	register(handle: PaneHandle): number;
	update(index: number, config: PaneConfig): void;
	deregister(index: number): void;
}
