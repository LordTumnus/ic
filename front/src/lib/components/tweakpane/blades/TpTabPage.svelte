<!--
  TpTabPage.svelte — A single tab page within a TpTabGroup.
  Finds its TabPageApi from the parent TpTabGroup context using pageIndex,
  then overrides 'ic-tp' context so child blades attach to this page.
-->
<script lang="ts">
  import { getContext, setContext } from 'svelte';
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
</script>

<!-- Sub-blade snippets within this tab page -->
{#each bladeTargets as target (target)}
  {#each childEntries[target] ?? [] as child (child.id)}
    {@render child.snippet()}
  {/each}
{/each}
