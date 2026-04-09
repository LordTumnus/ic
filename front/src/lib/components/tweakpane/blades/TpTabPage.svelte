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
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    label = $bindable(''),
    pageIndex = $bindable(0),
    bladeIndex = $bindable(0),
    childEntries = [] as ChildEntries,
  }: {
    id?: string;
    label?: string;
    pageIndex?: number;
    bladeIndex?: number;
    childEntries?: ChildEntries;
  } = $props();

  const tabCtx = getContext<TpTabGroupContext>('ic-tp-tabs');

  // Override context for sub-blades — they attach to this tab page
  const ctx: TpContext = $state({ container: undefined });
  setContext('ic-tp', ctx);


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

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}
