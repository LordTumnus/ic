<!--
  TpTabGroup.svelte — Tab container blade.
  Creates a TabApi with pages defined by child TpTabPage components.
  Each page is added via addPage() at creation time.

  Unlike Folder, TabApi needs all pages declared upfront in the addTab() call.
  We collect page titles from child entries, create all pages at once,
  then expose each TabPageApi via indexed context.
-->
<script lang="ts">
  import { getContext, setContext, getAllContexts } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { ChildEntries } from '$lib/types';
  import type { TabApi, TabPageApi } from 'tweakpane';

  export interface TpTabGroupContext {
    pages: TabPageApi[];
  }

  let {
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    targets = $bindable<string[]>([]),
    childEntries = {} as ChildEntries,
  }: {
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    targets?: string[];
    childEntries?: ChildEntries;
  } = $props();

  const parentCtx = getContext<TpContext>('ic-tp');

  // Context for tab pages to find their TabPageApi by index
  const tabCtx: TpTabGroupContext = $state({ pages: [] });
  setContext('ic-tp-tabs', tabCtx);

  const bladeTargets = $derived(
    (Array.isArray(targets) ? targets : targets ? [targets] : []).filter((t: string) =>
      t.startsWith('blade-'),
    ),
  );

  let tab: TabApi | undefined;

  $effect(() => {
    const container = parentCtx.container;
    if (!container) return;

    // Collect page titles from child entries
    const pageTargets = bladeTargets;
    const pageTitles: string[] = [];

    for (const target of pageTargets) {
      const entries = childEntries[target] ?? [];
      for (const entry of entries) {
        // Read label prop from child entry
        const label = entry.props?.label ?? '';
        pageTitles.push(label || 'Tab');
      }
    }

    if (pageTitles.length === 0) return;

    tab = container.addTab({
      pages: pageTitles.map((title) => ({ title })),
      index: bladeIndex,
    });

    // Expose page APIs so children can find theirs
    tabCtx.pages = tab.pages;

    return () => {
      tabCtx.pages = [];
      tab?.dispose();
      tab = undefined;
    };
  });

  $effect(() => {
    const d = disabled;
    const h = hidden;
    if (tab) {
      tab.disabled = d;
      tab.hidden = h;
    }
  });

  // Capture context (includes 'ic-tp' and 'ic-tp-tabs')
  const svelteCtx = getAllContexts();

  // Attach/detach tab page children
  let mountEl: HTMLDivElement;
  let attachedIds = new Set<string>();

  $effect(() => {
    if (!mountEl) return;
    const currentIds = new Set<string>();

    for (const target of bladeTargets) {
      for (const child of childEntries[target] ?? []) {
        currentIds.add(child.id);
        if (!attachedIds.has(child.id) && child.attach) {
          child.attach(mountEl, svelteCtx);
        }
      }
    }

    for (const id of attachedIds) {
      if (!currentIds.has(id)) {
        for (const target of Object.keys(childEntries)) {
          const entry = childEntries[target]?.find(e => e.id === id);
          if (entry?.detach) entry.detach();
        }
      }
    }

    attachedIds = currentIds;
  });
</script>

<div bind:this={mountEl} style="display: none"></div>
