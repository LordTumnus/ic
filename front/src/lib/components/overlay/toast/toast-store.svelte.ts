/**
 * Toast Store — centralized state for all active toasts.
 *
 * Manages both MATLAB-backed toasts (created via ic.Toast) and standalone
 * Svelte toasts (created via addToast()). The ToastContainer reads from
 * this store to render all toasts.
 *
 * Single-phase removal: removeToast() immediately splices from the array
 * and fires onClose. No exit animation — the toast just disappears.
 * This avoids the stacking bug where exiting toasts occupy flex space.
 *
 * Must be a .svelte.ts file for $state rune to work.
 */

import type { IconSource } from '$lib/utils/icons';

export interface ToastData {
  id: string;
  value: string;
  variant: string;
  duration: number;
  position: string;
  closable: boolean;
  icon: IconSource;
  onClose?: () => void;
}

export type ToastOptions = Partial<Omit<ToastData, 'id'>> & { value: string };

let toasts: ToastData[] = $state([]);

/**
 * Add a toast to the store.
 * @returns The toast ID (for later removal or updates).
 */
export function addToast(options: ToastOptions): string {
  const id = crypto.randomUUID();
  const toast: ToastData = {
    id,
    value: options.value,
    variant: options.variant ?? 'primary',
    duration: options.duration ?? 3,
    position: options.position ?? 'bottom',
    closable: options.closable ?? true,
    icon: options.icon ?? null,
    onClose: options.onClose,
  };
  toasts.push(toast);
  return id;
}

/**
 * Remove a toast immediately and fire its onClose callback.
 * Idempotent — safe to call multiple times for the same ID.
 */
export function removeToast(id: string): void {
  const idx = toasts.findIndex(t => t.id === id);
  if (idx === -1) return;
  const toast = toasts[idx];
  toasts.splice(idx, 1);
  toast.onClose?.();
}

/**
 * Force-remove a toast without firing onClose (used when MATLAB deletes
 * the component directly — the MATLAB object is already being destroyed).
 * Idempotent.
 */
export function forceRemoveToast(id: string): void {
  const idx = toasts.findIndex(t => t.id === id);
  if (idx !== -1) {
    toasts.splice(idx, 1);
  }
}

/**
 * Update toast properties (used by MATLAB bridge to sync prop changes).
 */
export function updateToast(id: string, changes: Partial<ToastData>): void {
  const toast = toasts.find(t => t.id === id);
  if (!toast) return;
  Object.assign(toast, changes);
}

/**
 * Get all active toasts (reactive).
 */
export function getToasts(): ToastData[] {
  return toasts;
}
