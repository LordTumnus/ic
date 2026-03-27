/**
 * KeyboardManager - Singleton that manages keyboard shortcut listeners per component.
 *
 * Attaches keydown listeners to component wrapper elements and matches
 * registered shortcuts. Optionally calls preventDefault() and/or
 * stopPropagation() on matched events when configured.
 */

import Registry from './registry';
import logger from './logger';

interface ParsedShortcut {
  original: string;
  key: string;
  ctrl: boolean;
  shift: boolean;
  alt: boolean;
  meta: boolean;
  preventDefault: boolean;
  stopPropagation: boolean;
}

interface ComponentKeyState {
  shortcuts: ParsedShortcut[];
  listener: ((e: KeyboardEvent) => void) | null;
}

interface ShortcutOptions {
  preventDefault?: boolean;
  stopPropagation?: boolean;
}

class KeyboardManager {
  private static _instance: KeyboardManager | null = null;
  private components = new Map<string, ComponentKeyState>();

  private constructor() {}

  static get instance(): KeyboardManager {
    if (!KeyboardManager._instance) {
      KeyboardManager._instance = new KeyboardManager();
    }
    return KeyboardManager._instance;
  }

  /** Initialize empty state for a component. */
  register(componentId: string): void {
    if (!this.components.has(componentId)) {
      this.components.set(componentId, { shortcuts: [], listener: null });
    }
  }

  /** Remove all shortcuts and detach listener for a component. */
  unregister(componentId: string): void {
    const state = this.components.get(componentId);
    if (state) {
      this.detachListener(componentId, state);
      this.components.delete(componentId);
    }
  }

  /** Add a shortcut for a component. Attaches listener if first shortcut. */
  addShortcut(componentId: string, shortcut: string, options?: ShortcutOptions): void {
    const state = this.components.get(componentId);
    if (!state) {
      logger.warn('KeyboardManager', 'addShortcut called for unregistered component', { componentId });
      return;
    }

    const parsed = parseShortcut(shortcut, options);

    // check if shortcut already exists (idempotent for same key combo)
    const existing = state.shortcuts.find((s) => shortcutsEqual(s, parsed));
    if (existing) {
      // merge options (OR — stricter wins)
      existing.preventDefault = existing.preventDefault || parsed.preventDefault;
      existing.stopPropagation = existing.stopPropagation || parsed.stopPropagation;
      return;
    }

    state.shortcuts.push(parsed);

    logger.debug('KeyboardManager', 'Added shortcut', { componentId, shortcut });

    // attach listener on first shortcut
    if (state.shortcuts.length === 1) {
      this.attachListener(componentId, state);
    }
  }

  /** Update options for an existing shortcut. */
  updateShortcut(componentId: string, shortcut: string, options: ShortcutOptions): void {
    const state = this.components.get(componentId);
    if (!state) return;

    const parsed = parseShortcut(shortcut);
    const existing = state.shortcuts.find((s) => shortcutsEqual(s, parsed));
    if (existing) {
      existing.preventDefault = options.preventDefault ?? existing.preventDefault;
      existing.stopPropagation = options.stopPropagation ?? existing.stopPropagation;
    }
  }

  /** Remove a shortcut for a component. Detaches listener if last shortcut. */
  removeShortcut(componentId: string, shortcut: string): void {
    const state = this.components.get(componentId);
    if (!state) return;

    const normalizedKey = parseShortcut(shortcut);
    state.shortcuts = state.shortcuts.filter(
      (s) => !shortcutsEqual(s, normalizedKey)
    );

    logger.debug('KeyboardManager', 'Removed shortcut', { componentId, shortcut });

    if (state.shortcuts.length === 0) {
      this.detachListener(componentId, state);
    }
  }

  /** Remove all shortcuts and detach listener for a component. */
  clearShortcuts(componentId: string): void {
    const state = this.components.get(componentId);
    if (!state) return;

    state.shortcuts = [];
    this.detachListener(componentId, state);

    logger.debug('KeyboardManager', 'Cleared all shortcuts', { componentId });
  }

  private attachListener(componentId: string, state: ComponentKeyState, retries = 0): void {
    if (state.listener) return;

    const element = document.getElementById(componentId);
    if (!element) {
      // element may not be mounted yet (async @insert). Retry next frame.
      if (retries < 3) {
        requestAnimationFrame(() => this.attachListener(componentId, state, retries + 1));
        return;
      }
      logger.warn('KeyboardManager', 'Cannot find element for listener after retries', { componentId });
      return;
    }

    state.listener = (e: KeyboardEvent) => {
      for (const shortcut of state.shortcuts) {
        if (matchesEvent(shortcut, e)) {
          // preventDefault also stops propagation to child handlers, since
          // JS-driven components (e.g. CodeMirror) don't check defaultPrevented
          if (shortcut.preventDefault) {
            e.preventDefault();
            e.stopPropagation();
          }
          if (shortcut.stopPropagation) {
            e.stopPropagation();
          }

          const component = Registry.instance.get(componentId);
          if (component) {
            component.publish('@keyPressed', {
              shortcut: shortcut.original,
              key: e.key,
              code: e.code,
            });
          }
        }
      }
    };

    // capture phase so the listener fires BEFORE child handlers (e.g. CodeMirror)
    element.addEventListener('keydown', state.listener, true);
  }

  private detachListener(componentId: string, state: ComponentKeyState): void {
    if (!state.listener) return;

    const element = document.getElementById(componentId);
    if (element) {
      element.removeEventListener('keydown', state.listener, true);
    }
    state.listener = null;
  }
}

/** Parse a shortcut string like "Ctrl+Shift+S" into modifiers + key. */
function parseShortcut(shortcut: string, options?: ShortcutOptions): ParsedShortcut {
  const parts = shortcut.split('+').map((p) => p.trim());
  const modifiers = new Set(parts.slice(0, -1).map((m) => m.toLowerCase()));
  const key = parts[parts.length - 1];

  return {
    original: shortcut,
    key: key.length === 1 ? key.toLowerCase() : key,
    ctrl: modifiers.has('ctrl'),
    shift: modifiers.has('shift'),
    alt: modifiers.has('alt'),
    meta: modifiers.has('meta') || modifiers.has('cmd'),
    preventDefault: options?.preventDefault ?? false,
    stopPropagation: options?.stopPropagation ?? false,
  };
}

/** Check if a KeyboardEvent matches a parsed shortcut. */
function matchesEvent(shortcut: ParsedShortcut, event: KeyboardEvent): boolean {
  if (shortcut.ctrl !== event.ctrlKey) return false;
  if (shortcut.shift !== event.shiftKey) return false;
  if (shortcut.alt !== event.altKey) return false;
  if (shortcut.meta !== event.metaKey) return false;

  // compare key case-insensitively for single characters
  const eventKey =
    event.key.length === 1 ? event.key.toLowerCase() : event.key;
  return eventKey === shortcut.key;
}

/** Check if two parsed shortcuts represent the same key combination. */
function shortcutsEqual(a: ParsedShortcut, b: ParsedShortcut): boolean {
  return (
    a.key === b.key &&
    a.ctrl === b.ctrl &&
    a.shift === b.shift &&
    a.alt === b.alt &&
    a.meta === b.meta
  );
}

export { KeyboardManager };
