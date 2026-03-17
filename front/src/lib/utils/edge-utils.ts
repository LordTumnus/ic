/**
 * edge-utils.ts — Shared utilities for custom node editor edge renderers.
 *
 * Provides:
 * - computeEdgePath: dispatches to the correct @xyflow path function based on geometry
 * - createPathSampler: reusable SVG path element for getPointAtLength
 * - evaluateExpression: cached expr-eval wrapper for SignalEdge waveforms
 * - EDGE_TYPE_MAP: MATLAB class name → SvelteFlow edge type key
 */

import {
  getBezierPath,
  getSmoothStepPath,
  getStraightPath,
  type Position,
} from '@xyflow/system';
import { Parser } from 'expr-eval';

// ── Path computation ────────────────────────────────────────────────────

export interface EdgePathParams {
  sourceX: number;
  sourceY: number;
  sourcePosition: Position;
  targetX: number;
  targetY: number;
  targetPosition: Position;
}

/**
 * Compute an SVG path string for an edge, dispatching to the correct
 * @xyflow path function based on the geometry string.
 *
 * Returns [path, labelX, labelY, offsetX, offsetY].
 */
export function computeEdgePath(
  geometry: string,
  params: EdgePathParams,
): [string, number, number, number, number] {
  switch (geometry) {
    case 'straight':
      return getStraightPath(params);
    case 'smoothstep':
      return getSmoothStepPath(params);
    case 'step':
      return getSmoothStepPath({ ...params, borderRadius: 0 });
    default:
      // 'bezier' or any unknown value
      return getBezierPath(params);
  }
}

// ── SVG path sampler ────────────────────────────────────────────────────

/**
 * Creates a reusable hidden SVG + path element for sampling points
 * along an SVG path via getPointAtLength / getTotalLength.
 *
 * The SVG is appended to the document body (required for path methods to work)
 * with zero dimensions and no pointer events.
 */
export function createPathSampler(): {
  setPath: (d: string) => void;
  getTotalLength: () => number;
  getPointAtLength: (len: number) => DOMPoint;
  destroy: () => void;
} {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('width', '0');
  svg.setAttribute('height', '0');
  svg.style.position = 'absolute';
  svg.style.pointerEvents = 'none';
  svg.style.opacity = '0';
  document.body.appendChild(svg);

  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  svg.appendChild(path);

  let currentD = '';

  return {
    setPath(d: string) {
      if (d !== currentD) {
        path.setAttribute('d', d);
        currentD = d;
      }
    },
    getTotalLength() {
      return path.getTotalLength();
    },
    getPointAtLength(len: number) {
      return path.getPointAtLength(len);
    },
    destroy() {
      svg.remove();
    },
  };
}

// ── Expression evaluator ────────────────────────────────────────────────

const parser = new Parser();
const expressionCache = new Map<string, ReturnType<Parser['parse']> | null>();

/**
 * Evaluate a math expression string at a given value of t.
 * Expressions are compiled once and cached for performance.
 * Returns 0 on parse error.
 */
/** Common math constants passed to every expression evaluation. */
const MATH_CONSTANTS = {
  pi: Math.PI,
  PI: Math.PI,
  e: Math.E,
  E: Math.E,
};

export function evaluateExpression(expression: string, t: number): number {
  let compiled = expressionCache.get(expression);
  if (compiled === undefined) {
    try {
      compiled = parser.parse(expression);
    } catch {
      compiled = null;
    }
    expressionCache.set(expression, compiled);
  }
  if (!compiled) return 0;
  try {
    return compiled.evaluate({ ...MATH_CONSTANTS, t }) as number;
  } catch {
    return 0;
  }
}

// ── Shared animation coordinator ────────────────────────────────────────

/**
 * Single rAF loop shared by all animated edges (FlowEdge + SignalEdge).
 * Each edge registers a callback; one rAF drives them all.
 * This eliminates N independent rAF loops (one per edge) which is the
 * primary performance bottleneck with many animated edges.
 */
type AnimationCallback = (timestamp: number) => void;

const animationCallbacks = new Set<AnimationCallback>();
let rafId: number | null = null;

function animationLoop(timestamp: number) {
  for (const cb of animationCallbacks) {
    cb(timestamp);
  }
  if (animationCallbacks.size > 0) {
    rafId = requestAnimationFrame(animationLoop);
  } else {
    rafId = null;
  }
}

/** Register a per-frame callback. Returns an unregister function. */
export function registerAnimationCallback(cb: AnimationCallback): () => void {
  animationCallbacks.add(cb);
  if (rafId === null) {
    rafId = requestAnimationFrame(animationLoop);
  }
  return () => {
    animationCallbacks.delete(cb);
    if (animationCallbacks.size === 0 && rafId !== null) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
  };
}

// ── Edge type map ───────────────────────────────────────────────────────

/** Maps MATLAB class names to SvelteFlow edge type keys. */
export const EDGE_TYPE_MAP: Record<string, string> = {
  'ic.node.StaticEdge': 'static',
  'ic.node.FlowEdge': 'flow',
  'ic.node.SignalEdge': 'signal',
};

// ── Marker helpers ──────────────────────────────────────────────────────

/** Valid arrow types for edge markers. */
export const ARROW_TYPES = ['arrow', 'diamond', 'circle'] as const;

/** Returns `url(#ic-marker-{type}-{edgeId})` or undefined for 'none'. */
export function markerUrl(
  edgeId: string,
  arrowType: string | undefined,
): string | undefined {
  if (!arrowType || arrowType === 'none') return undefined;
  return `url(#ic-marker-${arrowType}-${edgeId})`;
}
