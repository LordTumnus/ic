/**
 * Toast Registry — manages portal containers for toast stacking.
 *
 * Two modes of operation:
 *
 * 1. **MATLAB toasts** (via Toast.svelte): use the `toastPortal` Svelte action
 *    to move their DOM element into a shared flex container.
 *
 * 2. **Svelte-only toasts** (e.g. DevTools): call `addToast()` to imperatively
 *    create a ToastItem, mount it, and auto-dismiss after `duration` seconds.
 *
 * Containers (one per position: top/bottom) are lazily created as children of
 * #ic-frame so they inherit --ic-* CSS variables, and auto-cleaned when empty.
 *
 * Must be a .svelte.ts file for Svelte's mount/unmount imports.
 */

import { mount, unmount } from 'svelte';
import ToastItem from './ToastItem.svelte';
import type { IconSource } from '$lib/utils/icons';

// ---------------------------------------------------------------------------
// Container management
// ---------------------------------------------------------------------------

const containers = new Map<string, HTMLDivElement>();
const refCounts = new Map<string, number>();

/** Shared CSS for toast containers — applied inline (outside Svelte scope). */
const baseContainerStyle: Partial<CSSStyleDeclaration> = {
  position: 'fixed',
  zIndex: '9000',
  left: '50%',
  transform: 'translateX(-50%)',
  display: 'flex',
  gap: '8px',
  pointerEvents: 'none',
  maxWidth: 'calc(100vw - 32px)',
};

const positionStyle: Record<string, Partial<CSSStyleDeclaration>> = {
  top: { top: '16px', flexDirection: 'column' },
  bottom: { bottom: '16px', flexDirection: 'column-reverse' },
};

function getOrCreateContainer(position: string): HTMLDivElement {
  let container = containers.get(position);
  if (container) return container;

  const frame = document.getElementById('ic-frame');
  if (!frame) throw new Error('[toast-registry] #ic-frame not found');

  container = document.createElement('div');
  container.className = `ic-toast-container ic-toast-container--${position}`;
  Object.assign(container.style, baseContainerStyle, positionStyle[position] ?? positionStyle.bottom);

  frame.appendChild(container);
  containers.set(position, container);
  refCounts.set(position, 0);
  return container;
}

function incRef(position: string): void {
  refCounts.set(position, (refCounts.get(position) ?? 0) + 1);
}

function decRef(position: string): void {
  const count = Math.max(0, (refCounts.get(position) ?? 1) - 1);
  refCounts.set(position, count);
  if (count === 0) {
    const container = containers.get(position);
    if (container) {
      container.remove();
      containers.delete(position);
      refCounts.delete(position);
    }
  }
}

// ---------------------------------------------------------------------------
// Shared exit-animation styles (applied inline to portal wrappers)
// ---------------------------------------------------------------------------

const TRANSITION_DURATION = 150; // ms
const SAFETY_TIMEOUT = TRANSITION_DURATION + 50; // fallback if transitionend misses

function applyWrapperStyle(el: HTMLElement): void {
  el.style.transition = `opacity ${TRANSITION_DURATION}ms ease, transform ${TRANSITION_DURATION}ms ease`;
  el.style.opacity = '1';
  el.style.transform = 'translateY(0)';
}

function applyDismissStyle(el: HTMLElement): void {
  el.style.opacity = '0';
  el.style.transform = 'translateY(-8px)';
  el.style.pointerEvents = 'none';
}

// ---------------------------------------------------------------------------
// A) toastPortal — Svelte action for MATLAB-backed toasts
// ---------------------------------------------------------------------------

/**
 * Svelte action: portals an element into the correct toast flex container.
 *
 * Usage: `<div use:toastPortal={position}>`
 */
export function toastPortal(node: HTMLElement, position: string) {
  let currentPosition = position;
  const container = getOrCreateContainer(currentPosition);
  container.appendChild(node);
  incRef(currentPosition);

  return {
    update(newPosition: string) {
      if (newPosition === currentPosition) return;
      decRef(currentPosition);
      currentPosition = newPosition;
      const newContainer = getOrCreateContainer(currentPosition);
      newContainer.appendChild(node);
      incRef(currentPosition);
    },
    destroy() {
      node.remove();
      decRef(currentPosition);
    },
  };
}

// ---------------------------------------------------------------------------
// B) addToast — imperative API for Svelte-only toasts
// ---------------------------------------------------------------------------

export interface ToastOptions {
  value: string;
  variant?: string;
  duration?: number;
  position?: string;
  closable?: boolean;
  icon?: IconSource;
}

const standaloneToasts = new Map<string, { wrapper: HTMLElement; instance: Record<string, unknown>; position: string }>();

/**
 * Create a standalone toast (no MATLAB backing).
 * Returns an ID that can be passed to `removeToast()` for early dismissal.
 */
export function addToast(options: ToastOptions): string {
  const id = crypto.randomUUID();
  const pos = options.position ?? 'bottom';
  const duration = options.duration ?? 3;
  const container = getOrCreateContainer(pos);

  // Create portal wrapper
  const wrapper = document.createElement('div');
  applyWrapperStyle(wrapper);
  container.appendChild(wrapper);
  incRef(pos);

  // Dismiss logic
  let dismissed = false;

  function dismiss() {
    if (dismissed) return;
    dismissed = true;

    applyDismissStyle(wrapper);

    // Cleanup after transition (or safety timeout)
    const cleanup = () => {
      const entry = standaloneToasts.get(id);
      if (!entry) return;
      standaloneToasts.delete(id);
      unmount(entry.instance);
      wrapper.remove();
      decRef(entry.position);
    };

    wrapper.addEventListener('transitionend', (e) => {
      if (e.propertyName === 'opacity') cleanup();
    }, { once: true });

    setTimeout(cleanup, SAFETY_TIMEOUT);
  }

  // Mount ToastItem
  const instance = mount(ToastItem, {
    target: wrapper,
    props: {
      value: options.value,
      variant: options.variant ?? 'primary',
      position: pos,
      closable: options.closable ?? true,
      icon: options.icon ?? null,
      onclose: dismiss,
    },
  });

  standaloneToasts.set(id, { wrapper, instance, position: pos });

  // Auto-dismiss timer
  if (duration > 0) {
    setTimeout(dismiss, duration * 1000);
  }

  return id;
}

/**
 * Programmatically remove a standalone toast (early dismissal).
 */
export function removeToast(id: string): void {
  const entry = standaloneToasts.get(id);
  if (!entry) return;

  // Trigger dismiss animation
  standaloneToasts.delete(id);
  applyDismissStyle(entry.wrapper);

  const cleanup = () => {
    unmount(entry.instance);
    entry.wrapper.remove();
    decRef(entry.position);
  };

  entry.wrapper.addEventListener('transitionend', (e) => {
    if (e.propertyName === 'opacity') cleanup();
  }, { once: true });

  setTimeout(cleanup, SAFETY_TIMEOUT);
}
