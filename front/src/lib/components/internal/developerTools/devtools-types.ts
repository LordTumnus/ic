/**
 * Shared types for IC Developer Tools panels.
 *
 * ComponentInfo is fetched once from MATLAB via request('getComponentInfo')
 * and provides metadata that isn't available on the JS side (types,
 * validation constraints, hidden flags).
 */

export interface PropInfo {
	/** camelCase name used in Svelte props */
	name: string;
	/** Original MATLAB property name (PascalCase) */
	matlabName: string;
	/** MATLAB class of the current value (e.g. "string", "double", "logical") */
	type: string;
	/** Validation constraints parsed from MATLAB source */
	validation: PropValidation;
	/** Whether the property is hidden in MATLAB */
	hidden: boolean;
}

export interface PropValidation {
	/** Allowed values from mustBeMember validator */
	mustBeMember?: string[];
}

export interface EventInfo {
	/** camelCase name used in Svelte events */
	name: string;
	/** Original MATLAB event name (PascalCase) */
	matlabName: string;
}

export interface MethodInfo {
	/** camelCase name used in Svelte methods */
	name: string;
	/** Original MATLAB method name (PascalCase) */
	matlabName: string;
	/** Number of input arguments (excluding 'this') */
	nInputs: number;
}

export interface ComponentInfo {
	/** Fully qualified MATLAB class name */
	componentType: string;
	/** Component instance ID */
	componentId: string;
	/** Reactive property metadata */
	properties: PropInfo[];
	/** Reactive event metadata */
	events: EventInfo[];
	/** Reactive method metadata */
	methods: MethodInfo[];
	/** Mixin names (lowercase, e.g. "stylable", "requestable") */
	mixins: string[];
	/** Whether the component implements ic.mixin.Stylable */
	isStylable: boolean;
}

/** CSS rule collected from stylesheets */
export interface CssRule {
	selector: string;
	cssText: string;
}

/** Rules grouped by source */
export interface GroupedRules {
	component: CssRule[];
	dynamic: CssRule[];
	global: CssRule[];
}

/** Tab identifiers */
export type TabId = 'properties' | 'events' | 'methods' | 'styles';
