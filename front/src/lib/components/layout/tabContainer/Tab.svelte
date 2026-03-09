<!--
  Tab.svelte — Renders tab header content (icon, label, close button).

  Registers with parent TabContainer via context, pushes config updates
  reactively. Does NOT render the outer tab wrapper — TabContainer does that.
-->
<script lang="ts">
  import { getContext, onMount, onDestroy } from 'svelte';
  import type { TabContainerContext } from './tab-types';
  import { resolveIcon, type IconSource } from '$lib/utils/icons';

  const ICON_SIZES: Record<string, number> = { sm: 12, md: 14, lg: 16 };

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

  const ctx = getContext<TabContainerContext>('ic-tab-container');
  let myTarget = '';

  onMount(() => {
    myTarget = ctx.registerTab();
  });

  // Push config updates to parent whenever reactive props change
  $effect(() => {
    if (myTarget) {
      ctx.updateTab(myTarget, { label, closable, disabled, editable, icon });
    }
  });

  // Watch for rename signals from the parent container.
  // The assignment to `label` happens inside this component's own scope,
  // so Svelte's compiler correctly tracks the $bindable prop write.
  $effect(() => {
    const rp = ctx.lastRename;
    if (rp && myTarget && rp.target === myTarget) {
      label = rp.label;
    }
  });

  onDestroy(() => {
    if (myTarget) ctx.deregisterTab(myTarget);
  });

  const size = $derived(ctx.containerSize);

  const iconSvg = $derived.by(() => {
    if (!icon) return '';
    return resolveIcon(icon, ICON_SIZES[size] ?? 14);
  });

  function handleClose(e: MouseEvent) {
    e.stopPropagation();
    ctx.closeTab(myTarget);
  }
</script>

{#if iconSvg}
  <span class="ic-tc__icon">{@html iconSvg}</span>
{/if}
<span class="ic-tc__label">{label}</span>
{#if closable && !ctx.containerDisabled}
  <button
    class="ic-tc__close"
    tabindex={-1}
    aria-label="Close {label}"
    onmousedown={handleClose}
  >
    <svg width="8" height="8" viewBox="0 0 10 10" fill="none">
      <path d="M7.5 2.5L2.5 7.5M2.5 2.5L7.5 7.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
    </svg>
  </button>
{/if}
