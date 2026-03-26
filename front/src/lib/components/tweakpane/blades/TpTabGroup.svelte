<!--
  TpTabGroup.svelte — Tab container blade.
  Creates a TabApi with pages defined by child TpTabPage components.
  Each page is added via addPage() at creation time.

  Unlike Folder, TabApi needs all pages declared upfront in the addTab() call.
  We collect page titles from child entries, create all pages at once,
  then expose each TabPageApi via indexed context.
-->
<script lang="ts">
  import { getContext, setContext } from 'svelte';
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
</script>

<!-- Tab page snippets — each TpTabPage reads its TabPageApi from tabCtx -->
{#each bladeTargets as target (target)}
  {#each childEntries[target] ?? [] as child (child.id)}
    {@render child.snippet()}
  {/each}
{/each}
