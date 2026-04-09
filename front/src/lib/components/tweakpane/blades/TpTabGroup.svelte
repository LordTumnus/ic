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
  import DynamicChild from '$lib/core/DynamicChild.svelte';
  import type { TabApi, TabPageApi } from 'tweakpane';

  export interface TpTabGroupContext {
    pages: TabPageApi[];
  }

  let {
    id = '',
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    childEntries = [] as ChildEntries,
  }: {
    id?: string;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    childEntries?: ChildEntries;
  } = $props();

  const parentCtx = getContext<TpContext>('ic-tp');

  // Context for tab pages to find their TabPageApi by index
  const tabCtx: TpTabGroupContext = $state({ pages: [] });
  setContext('ic-tp-tabs', tabCtx);

  let tab: TabApi | undefined;

  $effect(() => {
    const container = parentCtx.container;
    if (!container) return;

    // Collect page titles from child entries
    const pageTitles: string[] = [];

    for (const entry of childEntries) {
      const label = (entry.props?.label as string) ?? '';
      pageTitles.push(label || 'Tab');
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

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}
