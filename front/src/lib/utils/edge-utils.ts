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

// ── Stateful feedback buffers (IIR / z^-1 semantics) ────────────────────
//
// SignalBuffer runs the IIR recurrence y[n] = f(x[n], y[n-1]) at a fixed
// sample rate over continuous time t.  It stores a sliding window of
// output samples indexed by their t value.  `read(t)` interpolates into
// this window, so edge renderers and display previews can query any t in
// the buffered range.
//
// Each animation frame, `advance(currentT)` extends the buffer from where
// it left off up to `currentT`.  The edge renderer then samples along the
// edge at various t values that fall within the buffered window.

const SAMPLE_RATE = 128;  // samples per unit of t (higher = smoother)
const BUFFER_SIZE = 2048; // max stored samples (covers ~16 units of t)

/**
 * Time-indexed IIR output buffer.
 *
 * Stores a sliding window of filtered output samples at fixed t intervals.
 * The combiner expression uses `__prev__` for the feedback term.
 */
export class SignalBuffer {
  combinerExpression = '';
  speed = 1;
  frequency = 2;
  /** Feedback delay in t-units.  __prev__ reads y(t - delayT). */
  delayT = 0.025;

  private samples: Float64Array = new Float64Array(BUFFER_SIZE);
  private head = 0;         // write pointer (circular)
  private count = 0;        // number of valid samples
  private tStart = 0;       // t value of oldest sample in buffer
  private tEnd = 0;         // t value of newest sample in buffer
  private compiledExpr: ReturnType<Parser['parse']> | null = null;
  private initialized = false;

  /** Compile the combiner expression. */
  recompile(): void {
    try {
      this.compiledExpr = parser.parse(this.combinerExpression);
    } catch {
      this.compiledExpr = null;
    }
  }

  /**
   * Advance the buffer up to time `targetT`.
   * Fills in all samples from where we left off to targetT at SAMPLE_RATE.
   * __prev__ reads from the buffer at `t - delayT` (true time-delayed feedback).
   */
  advance(targetT: number): void {
    if (!this.compiledExpr) return;
    const dt = 1 / SAMPLE_RATE;

    if (!this.initialized) {
      // Seed: compute warmup samples before targetT so IIR settles
      const warmupT = targetT - (this.frequency + 2);
      let t = warmupT;
      // Warmup without storing
      while (t < targetT - (BUFFER_SIZE / SAMPLE_RATE)) {
        const prev = this.read(t - this.delayT); // 0 during warmup
        const y = this.evalExpr(t, prev);
        this.writeSample(y);
        this.tEnd = t;
        t += dt;
      }
      // Reset and store from here
      this.samples.fill(0);
      this.head = 0;
      this.count = 0;
      this.tStart = t;
      while (t <= targetT) {
        const prev = this.read(t - this.delayT);
        const y = this.evalExpr(t, prev);
        this.writeSample(y);
        t += dt;
      }
      this.tEnd = t - dt;
      this.initialized = true;
      return;
    }

    // Extend from where we left off
    let t = this.tEnd + dt;
    while (t <= targetT) {
      const prev = this.read(t - this.delayT);
      const y = this.evalExpr(t, prev);
      this.writeSample(y);
      t += dt;
    }
    this.tEnd = t - dt;

    // Update tStart if buffer wrapped
    if (this.count >= BUFFER_SIZE) {
      this.tStart = this.tEnd - (BUFFER_SIZE - 1) / SAMPLE_RATE;
    }
  }

  /**
   * Read the filtered value at time t.
   * Linearly interpolates between stored samples.
   */
  read(t: number): number {
    if (this.count === 0) return 0;

    // Clamp to buffered range
    if (t <= this.tStart) return this.getSample(0);
    if (t >= this.tEnd) return this.getSample(this.count - 1);

    // Map t to fractional sample index
    const pos = (t - this.tStart) * SAMPLE_RATE;
    const i0 = Math.floor(pos);
    const i1 = Math.min(i0 + 1, this.count - 1);
    const frac = pos - i0;
    return this.getSample(i0) * (1 - frac) + this.getSample(i1) * frac;
  }

  /** Reset buffer state (e.g. when expression changes). */
  reset(): void {
    this.samples.fill(0);
    this.head = 0;
    this.count = 0;
    this.tStart = 0;
    this.tEnd = 0;
    this.initialized = false;
  }

  private evalExpr(t: number, prev: number): number {
    try {
      const y = this.compiledExpr!.evaluate({
        ...MATH_CONSTANTS, t, __prev__: prev,
      }) as number;
      return isFinite(y) ? y : 0;
    } catch {
      return 0;
    }
  }

  private writeSample(value: number): void {
    this.head = (this.head + 1) % BUFFER_SIZE;
    this.samples[this.head] = value;
    this.count = Math.min(this.count + 1, BUFFER_SIZE);
  }

  private getSample(indexFromStart: number): number {
    // Convert from "index from oldest" to circular buffer position
    const oldest = this.count >= BUFFER_SIZE
      ? (this.head + 1) % BUFFER_SIZE
      : 0;
    const idx = (oldest + indexFromStart) % BUFFER_SIZE;
    return this.samples[idx];
  }
}

// ── Feedback buffer registry ─────────────────────────────────────────────

const feedbackBuffers = new Map<string, SignalBuffer>();

/** Sanitize an ID for use in expression function names (replace non-alphanumeric with _). */
export function feedbackFnName(loopId: string): string {
  return '__fb_' + loopId.replace(/[^a-zA-Z0-9]/g, '_');
}

/**
 * Register (or update) a feedback loop buffer.
 *
 * @param loopId       Unique ID for this feedback loop (e.g. delay node ID)
 * @param combinerExpr Full combiner expression with `__prev__` for feedback
 * @param speed        Signal speed multiplier
 * @param frequency    Source signal frequency
 * @param delayT       Feedback delay in t-units (from Delay node's time)
 */
export function registerFeedbackLoop(
  loopId: string,
  combinerExpr: string,
  speed: number,
  frequency: number,
  delayT: number,
): SignalBuffer {
  let buf = feedbackBuffers.get(loopId);
  if (!buf) {
    buf = new SignalBuffer();
    feedbackBuffers.set(loopId, buf);
    parser.functions[feedbackFnName(loopId)] = (t: number) => buf!.read(t);
  }
  const exprChanged = buf.combinerExpression !== combinerExpr;
  buf.combinerExpression = combinerExpr;
  buf.speed = speed;
  buf.frequency = frequency;
  buf.delayT = Math.max(delayT, 1 / SAMPLE_RATE); // at least 1 sample
  if (exprChanged) {
    buf.recompile();
    buf.reset();
    expressionCache.clear();
  }
  return buf;
}

/** Remove a feedback loop. */
export function unregisterFeedbackLoop(loopId: string): void {
  feedbackBuffers.delete(loopId);
  delete parser.functions[feedbackFnName(loopId)];
  expressionCache.clear();
}

/**
 * Advance ALL feedback buffers to the current animation time.
 * Called once per frame BEFORE edge renderers.
 */
export function advanceFeedbackBuffers(globalTime: number): void {
  for (const buf of feedbackBuffers.values()) {
    // Convert globalTime to the t-domain used by edge renderers:
    // t = (1-frac)*freq + globalTime * BASE_SPEED * speed
    // The maximum t any renderer will request is freq + timeOffset
    const timeOffset = globalTime * 0.5 * buf.speed;
    const maxT = buf.frequency + timeOffset;
    buf.advance(maxT);
  }
}

/** Get the set of registered feedback loop IDs. */
export function getFeedbackLoopIds(): Set<string> {
  return new Set(feedbackBuffers.keys());
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

  // Advance feedback buffers BEFORE edge renderers sample them
  advanceFeedbackBuffers(globalTime);

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
