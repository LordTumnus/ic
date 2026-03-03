<!--
  Toast.svelte — MATLAB bridge component (headless).

  This component renders nothing. It syncs MATLAB reactive props to the
  shared toast store, and the ToastContainer handles all rendering.

  When the toast is dismissed (auto-timer or close button), the store's
  onClose callback uses `publish` to fire @event/closed directly to MATLAB.
  This bypasses the @listenEvent enable/disable mechanism, ensuring the
  event always reaches MATLAB regardless of timing.
-->
<script lang="ts">
  import type { PublishFn, Resolution } from '$lib/types';
  import type { IconSource } from '$lib/utils/icons';
  import {
    addToast,
    removeToast,
    forceRemoveToast,
    updateToast,
  } from './toast-store.svelte';
  import logger from '$lib/core/logger';

  let {
    value = $bindable(''),
    variant = $bindable('primary'),
    duration = $bindable(3),
    position = $bindable('bottom'),
    closable = $bindable(true),
    icon = $bindable(null as IconSource),
    publish,
    dismiss = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: string;
    variant?: string;
    duration?: number;
    position?: string;
    closable?: boolean;
    icon?: IconSource;
    publish?: PublishFn;
    dismiss?: () => Resolution;
  } = $props();

  // Register with the toast store on component init.
  // The onClose callback fires @event/closed directly via publish(),
  // bypassing the event enable/disable mechanism to avoid timing issues.
  const toastId = addToast({
    value,
    variant,
    duration,
    position,
    closable,
    icon,
    onClose: () => {
      logger.debug('Toast', 'closed', { toastId });
      publish?.('@event/closed', { timestamp: Date.now() });
    },
  });

  // Sync prop changes from MATLAB to the store
  $effect(() => {
    updateToast(toastId, { value, variant, duration, position, closable, icon });
  });

  // Wire up the dismiss reactive method
  $effect(() => {
    dismiss = (): Resolution => {
      removeToast(toastId);
      return { success: true, data: null };
    };
  });

  // Cleanup: force-remove on unmount (e.g., MATLAB delete(toast)).
  // Uses forceRemoveToast which does NOT fire onClose, since the MATLAB
  // component is already being destroyed at this point.
  $effect(() => {
    return () => {
      forceRemoveToast(toastId);
    };
  });
</script>
