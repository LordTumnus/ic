<!--
  Tab.svelte — Renders tab header content (indicator, icon, label, close button).

  Attached to the parent's .ic-tab__tab / .ic-tg__tab div via the attachable
  component pattern. Parent state classes (active, disabled, editing, shadow)
  live on the outer div; this component renders the inner content.

  The close button dispatches a bubbling "ic-tab-close" CustomEvent so the
  parent container can handle it without passing callbacks through the proxy.
-->
<script lang="ts">
  import { resolveIcon, type IconSource } from '$lib/utils/icons';

  let {
    label = $bindable(''),
    closable = $bindable(false),
    disabled = $bindable(false),
    editable = $bindable(false),
    icon = $bindable<IconSource>(null),
  }: {
    label?: string;
    closable?: boolean;
    disabled?: boolean;
    editable?: boolean;
    icon?: IconSource;
  } = $props();

  // Default icon size; CSS on the parent size-variant overrides via svg rules
  const ICON_SIZE = 16;

  function handleClose(e: PointerEvent) {
    e.stopPropagation();
    e.preventDefault();
    // Dispatch a bubbling custom event for the parent container to handle
    (e.currentTarget as HTMLElement).dispatchEvent(
      new CustomEvent('ic-tab-close', { bubbles: true })
    );
  }
</script>

<span class="ic-tab__indicator"></span>
{#if icon}
  {@const iconSvg = resolveIcon(icon, ICON_SIZE)}
  {#if iconSvg}
    <span class="ic-tab__icon">{@html iconSvg}</span>
  {/if}
{/if}
<span class="ic-tab__label">{label}</span>
{#if closable}
  <button
    class="ic-tab__close"
    tabindex={-1}
    aria-label="Close {label}"
    onpointerdown={handleClose}
  >
    <svg width="8" height="8" viewBox="0 0 10 10" fill="none">
      <path d="M7.5 2.5L2.5 7.5M2.5 2.5L7.5 7.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
    </svg>
  </button>
{/if}
