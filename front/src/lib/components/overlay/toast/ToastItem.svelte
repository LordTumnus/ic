<!--
  ToastItem.svelte — Pure visual toast notification.

  Renders the toast content with icon, message, and close button.
  Entrance animation via CSS keyframes. No dismiss logic — the
  parent (Toast.svelte or addToast) handles timer and lifecycle.
-->
<script lang="ts">
  import type { IconSource } from '$lib/utils/icons';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    value = '',
    variant = 'primary',
    position = 'bottom',
    closable = true,
    icon = null as IconSource,
    onclose,
  }: {
    value?: string;
    variant?: string;
    position?: string;
    closable?: boolean;
    icon?: IconSource;
    onclose?: () => void;
  } = $props();

  /** Default Lucide icon name per variant. */
  const defaultIcons: Record<string, string> = {
    primary: 'bell',
    success: 'circle-check',
    warning: 'triangle-alert',
    destructive: 'circle-x',
    info: 'info',
  };

  /** Resolve icon: custom if valid, otherwise variant default. */
  const iconSvg = $derived.by(() => {
    // Try custom icon first (guard against truthy-but-empty values like [])
    if (icon && typeof icon === 'string') {
      const svg = resolveIcon(icon, 16);
      if (svg) return svg;
    } else if (icon && typeof icon === 'object' && 'hash' in icon) {
      const svg = resolveIcon(icon, 16);
      if (svg) return svg;
    }
    // Fall back to variant default
    return resolveIcon(defaultIcons[variant] ?? 'bell', 16);
  });

  const closeSvg = resolveIcon('x', 14);
</script>

<div
  class="ic-toast ic-toast--{variant}"
  class:ic-toast--top={position === 'top'}
  class:ic-toast--bottom={position === 'bottom'}
  role="status"
>
  <span class="ic-toast__accent"></span>

  <span class="ic-toast__icon">
    {@html iconSvg}
  </span>

  <span class="ic-toast__message">{value}</span>

  {#if closable}
    <button
      class="ic-toast__close"
      onclick={onclose}
      aria-label="Dismiss"
    >
      {@html closeSvg}
    </button>
  {/if}
</div>

<style>
  /* ===== ENTRANCE ===== */

  @keyframes ic-toast-in-top {
    from { opacity: 0; transform: translateY(-12px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  @keyframes ic-toast-in-bottom {
    from { opacity: 0; transform: translateY(12px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  /* ===== TOAST ===== */

  .ic-toast {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 280px;
    max-width: 360px;
    padding: 8px 10px;
    border-radius: 2px;
    background: var(--ic-secondary);
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: var(--ic-font-size);
    box-shadow:
      0 2px 8px rgba(0, 0, 0, 0.18),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
    pointer-events: all;
    position: relative;
    overflow: clip;
  }

  /* Variant tint — pseudo-element overlays variant color at low opacity */
  .ic-toast::before {
    content: '';
    position: absolute;
    inset: 0;
    opacity: 0.2;
    pointer-events: none;
  }

  .ic-toast--primary::before   { background: var(--ic-primary); }
  .ic-toast--success::before   { background: var(--ic-success); }
  .ic-toast--warning::before   { background: var(--ic-warning); }
  .ic-toast--destructive::before { background: var(--ic-destructive); }
  .ic-toast--info::before      { background: var(--ic-info); }

  /* Entrance animations */
  .ic-toast--top {
    animation: ic-toast-in-top 0.2s ease-out both;
  }

  .ic-toast--bottom {
    animation: ic-toast-in-bottom 0.2s ease-out both;
  }

  /* ===== ACCENT STRIP ===== */

  .ic-toast__accent {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3px;
    z-index: 1;
  }

  .ic-toast--primary .ic-toast__accent { background: var(--ic-primary); }
  .ic-toast--success .ic-toast__accent { background: var(--ic-success); }
  .ic-toast--warning .ic-toast__accent { background: var(--ic-warning); }
  .ic-toast--destructive .ic-toast__accent { background: var(--ic-destructive); }
  .ic-toast--info .ic-toast__accent { background: var(--ic-info); }

  /* ===== ICON ===== */

  .ic-toast__icon {
    display: inline-flex;
    flex-shrink: 0;
    margin-left: 2px;
    position: relative;
  }

  .ic-toast--primary .ic-toast__icon { color: var(--ic-primary); }
  .ic-toast--success .ic-toast__icon { color: var(--ic-success); }
  .ic-toast--warning .ic-toast__icon { color: var(--ic-warning); }
  .ic-toast--destructive .ic-toast__icon { color: var(--ic-destructive); }
  .ic-toast--info .ic-toast__icon { color: var(--ic-info); }

  /* ===== MESSAGE ===== */

  .ic-toast__message {
    flex: 1;
    min-width: 0;
    line-height: 1.4;
    position: relative;
  }

  /* ===== CLOSE BUTTON ===== */

  .ic-toast__close {
    all: unset;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    border-radius: 2px;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    position: relative;
  }

  .ic-toast__close:hover {
    color: var(--ic-foreground);
    background: rgba(0, 0, 0, 0.08);
  }
</style>
