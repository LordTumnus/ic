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
	/** Whether the property has non-public SetAccess (not editable from outside) */
	readOnly: boolean;
	/** Structural type descriptor for complex values (from MATLAB introspectType) */
	typeInfo?: TypeInfo;
}

export interface PropValidation {
	/** Allowed values from mustBeMember validator */
	mustBeMember?: string[];
}

// --- Structural type descriptors (from MATLAB introspectType) ---

/** Classification of a MATLAB value's structure */
export type TypeInfoKind =
	| 'primitive'
	| 'array'
	| 'struct'
	| 'structArray'
	| 'object'
	| 'objectArray'
	| 'cell'
	| 'function_handle'
	| 'opaque'
	| 'truncated';

/** Recursive descriptor of a MATLAB value's type and shape */
export interface TypeInfo {
	kind: TypeInfoKind;
	/** MATLAB class name (e.g. "double", "ic.table.Column") */
	className: string;
	/** MATLAB size vector (e.g. [1,1] for scalar, [1,10] for 10-element array) */
	size: number[];
	/** Named children — for scalar struct (fields) and scalar object (properties) */
	children: TypeInfoChild[];
	/** Shared element type — for array, objectArray, structArray */
	elementTypeInfo?: TypeInfo;
}

/** One named field/property or indexed element within a TypeInfo */
export interface TypeInfoChild {
	/** Field or property name (MATLAB PascalCase). Empty for indexed entries. */
	key: string;
	/** 0-based index (only for cell array children) */
	index?: number;
	/** Validation constraints (e.g. mustBeMember) for object properties */
	validation?: PropValidation;
	/** Recursive type descriptor */
	typeInfo: TypeInfo;
}

/** Path segment for the setNestedProp request */
export interface PathSegment {
	/** Struct field or object property name (MATLAB PascalCase) */
	key?: string;
	/** 0-based array index */
	index?: number;
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

/** Origin of a CSS rule */
export type CssRuleSource = 'component' | 'dynamic' | 'global';

/** Single CSS property within a rule */
export interface CssProperty {
	/** kebab-case property name (e.g. "background-color") */
	name: string;
	/** Property value (e.g. "red") */
	value: string;
	/** True if a higher-specificity dynamic rule overrides this property */
	overridden: boolean;
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
	/** Where this rule originates from */
	source: CssRuleSource;
	/** Parsed individual properties (for per-property override styling) */
	properties: CssProperty[];
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

// --- Console types ---

import type { LogLevel } from '$lib/core/logger';

export type ConsoleEntryKind = 'log' | 'command' | 'result' | 'error';

export interface ConsoleEntry {
	/** Unique incrementing ID for keyed rendering */
	id: number;
	/** What kind of entry this is */
	kind: ConsoleEntryKind;
	/** Timestamp (Date.now()) */
	timestamp: number;
	/** Display text */
	text: string;
	/** Only for 'log' kind: the log level */
	level?: LogLevel;
	/** Only for 'log' kind: the source module */
	source?: string;
}
