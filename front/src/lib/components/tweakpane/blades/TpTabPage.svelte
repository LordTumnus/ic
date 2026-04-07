<!--
  TpTabPage.svelte — A single tab page within a TpTabGroup.
  Finds its TabPageApi from the parent TpTabGroup context using pageIndex,
  then overrides 'ic-tp' context so child blades attach to this page.
-->
<script lang="ts">
  import { getContext, setContext, getAllContexts } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { TpTabGroupContext } from './TpTabGroup.svelte';
  import type { ChildEntries } from '$lib/types';

  let {
    label = $bindable(''),
    pageIndex = $bindable(0),
    bladeIndex = $bindable(0),
    targets = $bindable<string[]>([]),
    childEntries = {} as ChildEntries,
  }: {
    label?: string;
    pageIndex?: number;
    bladeIndex?: number;
    targets?: string[];
    childEntries?: ChildEntries;
  } = $props();

  const tabCtx = getContext<TpTabGroupContext>('ic-tp-tabs');

  // Override context for sub-blades — they attach to this tab page
  const ctx: TpContext = $state({ container: undefined });
  setContext('ic-tp', ctx);

  const bladeTargets = $derived(
    (Array.isArray(targets) ? targets : targets ? [targets] : []).filter((t: string) =>
      t.startsWith('blade-'),
    ),
  );

  $effect(() => {
    const pages = tabCtx.pages;
    if (!pages || pages.length === 0) return;

    const page = pages[pageIndex];
    if (!page) return;

    ctx.container = page;

    return () => {
      ctx.container = undefined;
    };
  });

  // Capture context (includes overridden 'ic-tp' pointing to this tab page)
  const svelteCtx = getAllContexts();

  // Attach/detach sub-blade children
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
