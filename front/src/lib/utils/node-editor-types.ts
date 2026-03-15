import type { ChildEntries, ChildEntry } from '$lib/types';

/** Port definition extracted from nested childEntries. */
export interface PortDef {
	name: string;
	label: string;
	color: string;
	maxConnections: number;
}

/** Default port dot color when no color is specified. */
export const DEFAULT_PORT_COLOR = 'var(--ic-border)';

export function getPortColor(port: PortDef): string {
	return port.color || DEFAULT_PORT_COLOR;
}

/**
 * Extract port definitions from a node's nested childEntries.
 * Reads the reactive proxy chain: nodeEntry.props.childEntries[side] → PortDef[].
 */
export function extractPorts(
	nodeEntry: ChildEntry,
	side: 'inputs' | 'outputs',
): PortDef[] {
	const ce = nodeEntry.props.childEntries as ChildEntries | undefined;
	if (!ce?.[side]) return [];
	return ce[side].map((pe) => ({
		name: (pe.props.name as string) ?? '',
		label: (pe.props.label as string) ?? '',
		color: (pe.props.color as string) ?? '',
		maxConnections: (pe.props.maxConnections as number) ?? Infinity,
	}));
}
