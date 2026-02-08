/**
 * EffectManager - Creates and manages reactive JS effects on the frontend.
 *
 * Effects are JavaScript expressions that run inside Svelte's $effect system,
 * automatically re-executing when any tracked reactive state changes.
 *
 * Must be in a .svelte.ts file for $effect rune to work!
 */

import { untrack } from 'svelte';
import type { Resolution, JsEffectEventData } from '../types';
import type Component from './component.svelte';
import Registry from './registry';
import logger from './logger';

interface Effect {
  id: string;
  expression: string;
  cleanup: () => void;
}

class EffectManager {
  private static _instance: EffectManager | null = null;
  private effects: Map<string, Effect> = new Map();
  private executingEffects: Set<string> = new Set();

  static get instance(): EffectManager {
    if (!this._instance) {
      this._instance = new EffectManager();
    }
    return this._instance;
  }

  createEffect(data: JsEffectEventData): void {
    const { id, components, expression } = data;

    // Remove existing effect with same ID (idempotent)
    if (this.effects.has(id)) {
      this.removeEffect(id);
    }

    // Parse parameter names from the arrow function
    const paramMatch = expression.match(/^\s*\(([^)]*)\)\s*=>/);
    if (!paramMatch) {
      logger.error('EffectManager', 'Expression must be an arrow function', {
        effectId: id, expression
      });
      return;
    }
    const params = paramMatch[1].split(',').map(p => p.trim()).filter(Boolean);

    // Build proxies in parameter order
    const proxies: unknown[] = [];
    for (const param of params) {
      const idOrIds = components[param];
      if (idOrIds === undefined) {
        logger.error('EffectManager', `No component mapped to parameter "${param}"`, {
          effectId: id, components
        });
        return;
      }

      if (Array.isArray(idOrIds)) {
        const arr: unknown[] = [];
        for (const cid of idOrIds) {
          const component = Registry.instance.get(cid) as Component | undefined;
          if (!component) {
            logger.error('EffectManager', 'Component not found', {
              effectId: id, param, componentId: cid
            });
            return;
          }
          arr.push(this.createComponentProxy(component));
        }
        proxies.push(arr);
      } else {
        const component = Registry.instance.get(idOrIds) as Component | undefined;
        if (!component) {
          logger.error('EffectManager', 'Component not found', {
            effectId: id, param, componentId: idOrIds
          });
          return;
        }
        proxies.push(this.createComponentProxy(component));
      }
    }

    // Compile the arrow function
    let fn: Function;
    try {
      fn = new Function('return ' + expression)();
    } catch (error) {
      logger.error('EffectManager', 'Expression compilation failed', {
        effectId: id, expression,
        error: error instanceof Error ? error.message : String(error)
      });
      return;
    }

    // Create reactive effect
    const cleanup = $effect.root(() => {
      $effect(() => {
        // Guard against self-referential cycles
        if (this.executingEffects.has(id)) {
          logger.warn('EffectManager', 'Cycle detected, skipping', { effectId: id });
          return;
        }

        this.executingEffects.add(id);
        try {
          fn(...proxies);
        } catch (error) {
          logger.error('EffectManager', 'Effect execution failed', {
            effectId: id, expression,
            error: error instanceof Error ? error.message : String(error)
          });
        } finally {
          this.executingEffects.delete(id);
        }
      });
    });

    this.effects.set(id, { id, expression, cleanup });
    logger.info('EffectManager', 'Effect created', { effectId: id, expression });
  }

  removeEffect(id: string): void {
    const effect = this.effects.get(id);
    if (effect) {
      effect.cleanup();
      this.effects.delete(id);
      logger.info('EffectManager', 'Effect removed', { effectId: id });
    }
  }

  clear(): void {
    for (const effect of this.effects.values()) {
      effect.cleanup();
    }
    this.effects.clear();
    logger.info('EffectManager', 'All effects cleared');
  }

  /**
   * Create a proxy exposing props, methods, el, id, type.
   *
   * - `props`: Direct reference to svelteProps. Reads are tracked by $effect
   *   (since svelteProps getters read from $state). Writes go through the
   *   setter which updates $state AND publishes to MATLAB.
   *
   * - `methods`: Untracked wrappers. Reading a method implementation from
   *   _methodState would create a spurious dependency (the $effect would
   *   re-run whenever the Svelte component re-assigns the method via its
   *   own $effect). We use untrack() to prevent this.
   *
   * - `el`: Live getter (not a snapshot). The DOM element may not exist at
   *   proxy creation time, or may change on re-mount.
   */
  private createComponentProxy(component: Component): Record<string, unknown> {
    // Build untracked methods object using names stored on the component
    const methods: Record<string, (data?: unknown) => Resolution | undefined> = {};
    for (const name of component.methodNames) {
      methods[name] = (data?: unknown) => {
        return untrack(() => {
          const fn = component.svelteProps[name];
          if (typeof fn === 'function') {
            return fn(data) as Resolution;
          }
        });
      };
    }

    return {
      props: component.svelteProps,
      methods,
      // Live getter — always returns the current DOM element (or null)
      get el() {
        return document.getElementById(component.id);
      },
      id: component.id,
      type: component.type
    };
  }
}

export default EffectManager;
