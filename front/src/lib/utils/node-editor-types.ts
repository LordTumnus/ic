import type { IconSource } from '$lib/utils/icons';

/** Port definition received from MATLAB's ic.node.Port jsonencode. */
export interface PortDef {
	name: string;
	label: string;
	color: string;
	maxConnections: number;
}

/** Data object passed to EditorNode.svelte via Svelte Flow's node.data. */
export interface EditorNodeData {
	label: string;
	inputs: PortDef[];
	outputs: PortDef[];
	disabled: boolean;
	color: string;
	icon: IconSource;
}

/** Default port dot color when no color is specified. */
export const DEFAULT_PORT_COLOR = 'var(--ic-border)';

export function getPortColor(port: PortDef): string {
	return port.color || DEFAULT_PORT_COLOR;
}
