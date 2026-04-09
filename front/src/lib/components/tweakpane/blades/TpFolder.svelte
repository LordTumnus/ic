<!--
  TpFolder.svelte — Collapsible folder container blade.
  Creates a FolderApi and overrides the 'ic-tp' context so child blades
  attach to this folder instead of the root Pane.
-->
<script lang="ts">
  import { getContext, setContext } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';
  import type { FolderApi } from 'tweakpane';

  let {
    id = '',
    label = $bindable(''),
    expanded = $bindable(true),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    childEntries = [] as ChildEntries,
  }: {
    id?: string;
    label?: string;
    expanded?: boolean;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    childEntries?: ChildEntries;
  } = $props();

  const parentCtx = getContext<TpContext>('ic-tp');

  // Override context for sub-blades
  const ctx: TpContext = $state({ container: undefined });
  setContext('ic-tp', ctx);


  let folder: FolderApi | undefined;

  $effect(() => {
    const container = parentCtx.container;
    if (!container) return;

    folder = container.addFolder({
      title: label || undefined,
      expanded,
      index: bladeIndex,
    });

    ctx.container = folder;

    return () => {
      ctx.container = undefined;
      folder?.dispose();
      folder = undefined;
    };
  });

  $effect(() => {
    const e = expanded;
    const d = disabled;
    const h = hidden;
    if (folder) {
      folder.expanded = e;
      folder.disabled = d;
      folder.hidden = h;
    }
  });


</script>

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}
