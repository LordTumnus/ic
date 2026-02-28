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
	/** Child components with metadata (recursive, empty if not a container) */
	children: ChildComponentInfo[];
}

/** Child component metadata — extends ComponentInfo with target slot name. */
export interface ChildComponentInfo extends ComponentInfo {
	/** Target slot this child occupies in the parent (e.g., "icon", "default") */
	target: string;
}

/** CSS rule collected from stylesheets */
export interface CssRule {
	/** Raw selector (for internal matching) */
	selector: string;
	/** Cleaned selector for display (no .svelte-* hashes) */
	displaySelector: string;
	cssText: string;
	/** Whether this rule currently matches an element in the component */
	matches: boolean;
}

/** Rules grouped by source */
export interface GroupedRules {
	component: CssRule[];
	dynamic: CssRule[];
	global: CssRule[];
}

/** Serialized representation of a DOM node for the DOM tree */
export interface DomNode {
	/** Unique path-based identifier (e.g., "0", "0-1", "0-1-2") */
	id: string;
	/** Node type: 1=Element, 3=Text */
	nodeType: number;
	/** Tag name (lowercase) for element nodes */
	tagName?: string;
	/** Attributes as key-value pairs (cleaned of svelte internals) */
	attributes?: Array<{ name: string; value: string }>;
	/** Text content (for text nodes or short inline text) */
	textContent?: string;
	/** Child nodes */
	children: DomNode[];
	/** Whether this node has children */
	hasChildren: boolean;
	/** Live reference to the actual DOM node (for highlight/pick) */
	element?: Element | Text;
}

/** Tab identifiers */
export type TabId = 'properties' | 'events' | 'methods' | 'styles' | 'dom';
