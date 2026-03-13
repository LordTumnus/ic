/** Port definition received from MATLAB's ic.node.Port jsonencode. */
export interface PortDef {
	name: string;
	label: string;
	type: string;
	maxConnections: number;
}
