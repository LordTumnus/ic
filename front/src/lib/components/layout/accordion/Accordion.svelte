<!--
  Accordion.svelte — Collapsible panel container.

  Panel config (label, icon, open, disabled) is read from AccordionPanel
  children via the ChildEntry proxy — same pattern as TabContainer reading
  Tab props.

  Collapse uses a measuring wrapper: on toggle, we read scrollHeight and
  set an explicit max-height for a CSS transition, then clear it after
  the transition ends (so content can grow dynamically while open).
-->
<script lang="ts">
  import type { ChildEntries } from '$lib/types';
  import { resolveIcon, type IconSource } from '$lib/utils/icons';
  import { tick } from 'svelte';

  const ICON_SIZES: Record<string, number> = { sm: 12, md: 14, lg: 16 };

  let {
    multiple = $bindable(true),
    size = $bindable<'sm' | 'md' | 'lg'>('md'),
    disabled = $bindable(false),
    targets = $bindable<string[]>([]),
    panelToggled,
    childEntries = {} as ChildEntries,
  }: {
    multiple?: boolean;
    size?: 'sm' | 'md' | 'lg';
    disabled?: boolean;
    targets?: string[];
    panelToggled?: (data?: unknown) => void;
    childEntries?: ChildEntries;
  } = $props();

  // --- Panel config resolution ---

  interface PanelConfig {
    label: string;
    icon: IconSource;
    open: boolean;
    disabled: boolean;
  }

  function getConfig(target: string): PanelConfig | undefined {
    const entry = childEntries[target]?.[0];
    if (!entry || entry.props.label === undefined) return undefined;
    return {
      label: (entry.props.label as string) ?? '',
      icon: (entry.props.icon as IconSource) ?? null,
      open: (entry.props.open as boolean) ?? false,
      disabled: (entry.props.disabled as boolean) ?? false,
    };
  }

  const panelTargets = $derived(targets.filter((t) => t.startsWith('panel-')));

  // --- Content element refs for animated collapse ---

  let contentEls: Record<string, HTMLDivElement> = {};

  // --- Toggle ---

  /**
   * Animate a single panel's content element closed.
   * Freezes current height, then transitions to 0.
   * After transition, clears inline style so CSS class takes over.
   */
  function animateClose(el: HTMLDivElement) {
    const fullHeight = el.scrollHeight;
    el.style.maxHeight = fullHeight + 'px';
    void el.offsetHeight;
    el.style.maxHeight = '0px';
    el.addEventListener('transitionend', () => {
      el.style.maxHeight = '';
    }, { once: true });
  }

  function togglePanel(target: string) {
    const config = getConfig(target);
    if (!config || disabled || config.disabled) return;

    const entry = childEntries[target]?.[0];
    if (!entry) return;

    const newOpen = !config.open;
    const el = contentEls[target];

    // Single-open mode: close others first
    if (!multiple && newOpen) {
      for (const t of panelTargets) {
        if (t === target) continue;
        const other = childEntries[t]?.[0];
        if (other && (other.props.open as boolean)) {
          const otherEl = contentEls[t];
          if (otherEl) animateClose(otherEl);
          other.props.open = false;
        }
      }
    }

    if (newOpen) {
      // Opening: set prop (adds --open class → max-height: none),
      // then override with inline animation from 0 to scrollHeight.
      entry.props.open = true;
      tick().then(() => {
        if (!el) return;
        const fullHeight = el.scrollHeight;
        if (fullHeight === 0) return;       // nothing to animate
        el.style.maxHeight = '0px';         // override CSS 'none'
        void el.offsetHeight;               // force reflow
        el.style.maxHeight = fullHeight + 'px';
        el.addEventListener('transitionend', () => {
          el.style.maxHeight = '';           // clear → CSS 'none' takes over
        }, { once: true });
      });
    } else {
      // Closing: freeze height inline, set prop (removes --open class),
      // then animate to 0.
      if (el) animateClose(el);
      entry.props.open = false;
    }

    panelToggled?.({ value: { target, open: newOpen } });
  }

  function handleKeyDown(e: KeyboardEvent, target: string) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      togglePanel(target);
    }
  }
</script>

<div class="ic-ac" class:ic-ac--disabled={disabled}>
  {#each panelTargets as target (target)}
    {@const config = getConfig(target)}
    {@const entry = childEntries[target]?.[0]}
    {@const isOpen = config?.open ?? false}
    {@const isDisabled = config?.disabled ?? false}
    {#if config}
      <div class="ic-ac__panel" class:ic-ac__panel--open={isOpen}>
        <!-- Header -->
        <div
          class="ic-ac__header"
          class:ic-ac__header--open={isOpen}
          class:ic-ac__header--disabled={isDisabled}
          class:ic-ac__header--sm={size === 'sm'}
          class:ic-ac__header--md={size === 'md'}
          class:ic-ac__header--lg={size === 'lg'}
          role="button"
          tabindex={isDisabled || disabled ? -1 : 0}
          aria-expanded={isOpen}
          aria-disabled={isDisabled || disabled}
          onclick={() => togglePanel(target)}
          onkeydown={(e) => handleKeyDown(e, target)}
        >
          <span class="ic-ac__indicator" class:ic-ac__indicator--open={isOpen}></span>

          <!-- Chevron -->
          <span class="ic-ac__chevron" class:ic-ac__chevron--open={isOpen}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <path d="M4 2L8 6L4 10" stroke="currentColor" stroke-width="1.5"
                    stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </span>

          {#if config.icon}
            {@const iconSvg = resolveIcon(config.icon, ICON_SIZES[size] ?? 14)}
            {#if iconSvg}
              <span class="ic-ac__icon">{@html iconSvg}</span>
            {/if}
          {/if}

          <span class="ic-ac__label">{config.label}</span>
        </div>

        <!-- Collapsible content -->
        <div
          bind:this={contentEls[target]}
          class="ic-ac__content"
          class:ic-ac__content--open={isOpen}
        >
          <div class="ic-ac__body">
            {#if entry}
              {@render entry.snippet()}
            {/if}
          </div>
        </div>
      </div>
    {/if}
  {/each}
</div>

<style>
  /* -- Container -- */
  .ic-ac {
    display: flex;
    flex-direction: column;
    width: 100%;
    font-family: var(--ic-font-family);
    font-size: var(--ic-font-size);
  }

  .ic-ac--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* -- Panel -- */
  .ic-ac__panel {
    border-bottom: 1px solid var(--ic-border);
  }

  .ic-ac__panel:last-child {
    border-bottom: none;
  }

  /* -- Header -- */
  .ic-ac__header {
    position: relative;
    display: flex;
    align-items: center;
    gap: 6px;
    background-color: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    border: 1px solid transparent;
    cursor: pointer;
    user-select: none;
    transition: background-color 0.12s ease, color 0.12s ease;
    font-family: inherit;
    font-weight: 500;
  }

  /* Sizes */
  .ic-ac__header--sm { padding: 4px 10px; font-size: 0.75rem; }
  .ic-ac__header--md { padding: 6px 14px; font-size: 0.8125rem; }
  .ic-ac__header--lg { padding: 8px 18px; font-size: 0.875rem; }

  /* Hover */
  .ic-ac__header:hover:not(.ic-ac__header--disabled) {
    background-color: rgba(255, 255, 255, 0.04);
    color: var(--ic-foreground);
  }

  /* Open */
  .ic-ac__header--open {
    background-color: var(--ic-background);
    color: var(--ic-foreground);
  }

  /* Focus */
  .ic-ac__header:focus-visible {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
    outline: none;
  }

  /* Disabled */
  .ic-ac__header--disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  /* -- Left indicator -- */
  .ic-ac__indicator {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3px;
    background: transparent;
    transition: background-color 0.15s ease;
  }

  .ic-ac__indicator--open {
    background-color: var(--ic-primary);
  }

  /* -- Chevron -- */
  .ic-ac__chevron {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: inherit;
    line-height: 0;
    transition: transform 0.15s ease;
  }

  .ic-ac__chevron--open {
    transform: rotate(90deg);
  }

  /* -- Icon -- */
  .ic-ac__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: inherit;
    line-height: 0;
  }

  /* -- Label -- */
  .ic-ac__label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    line-height: 1.2;
    flex: 1;
    min-width: 0;
  }

  /* -- Collapsible content -- */
  .ic-ac__content {
    max-height: 0;
    overflow: clip;
    transition: max-height 0.2s ease;
  }

  .ic-ac__content--open {
    max-height: none;
  }

  /* -- Body (inner padding) -- */
  .ic-ac__body {
    border-top: 1px solid var(--ic-border);
    background-color: var(--ic-background);
  }
</style>
