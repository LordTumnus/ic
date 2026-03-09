import type { IconSource } from '$lib/utils/icons';

export interface TabConfig {
	label: string;
	closable: boolean;
	disabled: boolean;
	editable: boolean;
	icon: IconSource;
}
