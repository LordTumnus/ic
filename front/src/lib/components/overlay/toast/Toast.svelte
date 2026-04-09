<!--
  Toast.svelte — Ephemeral notification overlay.

  Each Toast renders its own UI and portals it into a shared flex
  container (managed by toast-registry) for stacking. Auto-dismisses
  after `duration` seconds (0 = persistent).

  Exit animation uses CSS transitions via inline styles (applied by
  the registry), NOT Svelte `out:` directives — the snippet system
  unmounts components immediately, so Svelte transitions never run.

  After the exit transition completes, @event/closed is published
  to MATLAB, whose ClosedListener auto-deletes the Toast object.
-->
<script lang="ts">
  import type { PublishFn, Resolution } from '$lib/types';
  import type { IconSource } from '$lib/utils/icons';
  import { toastPortal } from './toast-registry.svelte';
  import ToastItem from './ToastItem.svelte';
  import logger from '$lib/core/logger';

  const TRANSITION_MS = 150;
  const SAFETY_TIMEOUT_MS = TRANSITION_MS + 50;

  let {
    id = '',
    value = $bindable(''),
    variant = $bindable('primary'),
    duration = $bindable(3),
    position = $bindable('bottom'),
    closable = $bindable(true),
    icon = $bindable(null as IconSource),
    publish,
    dismiss = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    value?: string;
    variant?: string;
    duration?: number;
    position?: string;
    closable?: boolean;
    icon?: IconSource;
    publish?: PublishFn;
    dismiss?: () => Resolution;
  } = $props();

  let portalEl: HTMLDivElement;

  /** Whether the toast is in its exit-animation phase. */
  let dismissing = false;

  /** Auto-dismiss timer handle. */
  let autoTimer: ReturnType<typeof setTimeout> | null = null;

  /**
   * Start the dismiss sequence.
   * Applies the exit transition, then fires @event/closed after it completes.
   * Idempotent — safe to call multiple times.
   */
  function handleDismiss() {
    if (dismissing) return;
    dismissing = true;
    clearAutoTimer();

    // Apply exit animation via inline styles (matches registry's applyDismissStyle)
    if (portalEl) {
      portalEl.style.opacity = '0';
      portalEl.style.transform = 'translateY(-8px)';
      portalEl.style.pointerEvents = 'none';

      portalEl.addEventListener('transitionend', (e) => {
        if (e.propertyName === 'opacity') fireClose();
      }, { once: true });
    }

    // Safety timeout in case transitionend doesn't fire
    setTimeout(fireClose, SAFETY_TIMEOUT_MS);
  }

  /** Fire the MATLAB Closed event (idempotent). */
  let closeFired = false;
  function fireClose() {
    if (closeFired) return;
    closeFired = true;
    logger.debug('Toast', 'closed');
    publish?.('@event/closed', { timestamp: Date.now() });
  }

  function clearAutoTimer() {
    if (autoTimer !== null) {
      clearTimeout(autoTimer);
      autoTimer = null;
    }
  }

  // Auto-dismiss timer — restarts when duration changes
  $effect(() => {
    clearAutoTimer();
    if (duration > 0 && !dismissing) {
      autoTimer = setTimeout(handleDismiss, duration * 1000);
    }
    return () => clearAutoTimer();
  });

  // Wire up the dismiss reactive method
  $effect(() => {
    dismiss = (): Resolution => {
      handleDismiss();
      return { success: true, data: null };
    };
  });
</script>

<div {id}
  bind:this={portalEl}
  class="ic-toast-portal"
  use:toastPortal={position}
>
  <ToastItem
    {value}
    {variant}
    {position}
    {closable}
    {icon}
    onclose={handleDismiss}
  />
</div>

<style>
  .ic-toast-portal {
    transition: opacity 150ms ease, transform 150ms ease;
    opacity: 1;
    transform: translateY(0);
  }
</style>
