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

// ── Custom functions ─────────────────────────────────────────────────────
// Register wave generators, envelopes, and utility functions on the parser.
// All wave functions use t as the time variable. Users combine with frequency
// scaling: sq(2*t) = 2Hz square wave, pulse(4*t, 0.05) = 4Hz narrow pulse.

// Utility
parser.functions.clamp = (x: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, x));
parser.functions.mod = (x: number, y: number) => ((x % y) + y) % y;
parser.functions.lerp = (a: number, b: number, t: number) => a + (b - a) * t;

// Wave generators
parser.functions.sq = (t: number, duty = 0.5) => {
  const phase = ((t % 1) + 1) % 1;
  return phase < duty ? 1 : -1;
};
parser.functions.saw = (t: number) => 2 * (t - Math.floor(t + 0.5));
parser.functions.tri = (t: number, rise = 0.5) => {
  const phase = ((t % 1) + 1) % 1;
  if (phase < rise) return rise > 0 ? 2 * (phase / rise) - 1 : -1;
  return rise < 1 ? 1 - 2 * ((phase - rise) / (1 - rise)) : 1;
};
parser.functions.pulse = (t: number, width = 0.1) => {
  const phase = ((t % 1) + 1) % 1;
  return phase < width ? 1 : 0;
};
parser.functions.step = (t: number, edge = 0) => {
  if (edge <= 0) return t >= 0 ? 1 : 0;
  return 1 / (1 + Math.exp(-t * 20 / edge));
};
parser.functions.rect = (t: number, width = 1) => Math.abs(t) <= width / 2 ? 1 : 0;
parser.functions.sinc = (t: number) => {
  if (Math.abs(t) < 1e-10) return 1;
  const pt = Math.PI * t;
  return Math.sin(pt) / pt;
};
parser.functions.noise = (t: number, rate = 8) => {
  const s = Math.floor(t * rate);
  return Math.sin(s * 127.1) * Math.cos(s * 269.3);
};

// Envelope / modulation
parser.functions.env = (t: number, attack = 0.1, decay = 1) => {
  if (t < 0) return 0;
  if (t < attack) return attack > 0 ? t / attack : 1;
  return Math.exp(-decay * (t - attack));
};
parser.functions.smooth = (t: number, width = 1) => {
  const x = Math.min(1, Math.max(0, t / width));
  return x * x * (3 - 2 * x);
};
parser.functions.exp_decay = (t: number, rate = 1) => Math.exp(-rate * Math.max(0, t));

// Selection / switching: sel(ctrl, in1, in2) — selects in1 by default, in2 when ctrl >= 1
parser.functions.sel = (ctrl: number, a: number, b: number) => ctrl >= 1 ? b : a;

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

// ── Global clock + shared animation coordinator ─────────────────────────
//
// Single rAF loop shared by all animated edges (FlowEdge + SignalEdge).
// A global clock tracks elapsed time with play/pause and speed control.
// All edge callbacks receive the same `globalTime` value each frame,
// ensuring coherent animations across the entire graph.
// Edges no longer track their own startTime — remounting does not reset.

type AnimationCallback = (globalTime: number) => void;

const animationCallbacks = new Set<AnimationCallback>();
let rafId: number | null = null;

// Global clock state
let globalTime = 0;
let playing = true;
let speedMultiplier = 1;
let lastTimestamp: number | null = null;

function animationLoop(timestamp: number) {
  // Advance global clock
  if (lastTimestamp !== null) {
    const deltaSec = (timestamp - lastTimestamp) / 1000;
    if (playing) {
      globalTime += deltaSec * speedMultiplier;
    }
  }
  lastTimestamp = timestamp;

  // Dispatch to all edge callbacks with the shared global time
  for (const cb of animationCallbacks) {
    cb(globalTime);
  }
  if (animationCallbacks.size > 0) {
    rafId = requestAnimationFrame(animationLoop);
  } else {
    rafId = null;
    lastTimestamp = null;
  }
}

/** Register a per-frame callback. Returns an unregister function. */
export function registerAnimationCallback(cb: AnimationCallback): () => void {
  animationCallbacks.add(cb);
  if (rafId === null) {
    lastTimestamp = null; // reset so first frame has no delta
    rafId = requestAnimationFrame(animationLoop);
  }
  return () => {
    animationCallbacks.delete(cb);
    if (animationCallbacks.size === 0 && rafId !== null) {
      cancelAnimationFrame(rafId);
      rafId = null;
      lastTimestamp = null;
    }
  };
}

// ── Clock control API ───────────────────────────────────────────────────

export function getGlobalTime(): number { return globalTime; }
export function isPlaying(): boolean { return playing; }
export function getSpeed(): number { return speedMultiplier; }

export function setPlaying(value: boolean): void { playing = value; }
export function setSpeed(value: number): void { speedMultiplier = value; }

export function resetGlobalTime(): void {
  globalTime = 0;
  lastTimestamp = null;
}

// ── Edge type map ───────────────────────────────────────────────────────

/** Maps MATLAB class names to SvelteFlow edge type keys.
 * With unified Edge, all edges use the 'default' type.
 * Thin wrapper subclass names kept for backward compatibility. */
export const EDGE_TYPE_MAP: Record<string, string> = {
  'ic.node.Edge': 'default',
  'ic.node.StaticEdge': 'default',
  'ic.node.FlowEdge': 'default',
  'ic.node.SignalEdge': 'default',
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
