<!--
  TpFolder.svelte — Collapsible folder container blade.
  Creates a FolderApi and overrides the 'ic-tp' context so child blades
  attach to this folder instead of the root Pane.
-->
<script lang="ts">
  import { getContext, setContext } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { ChildEntries } from '$lib/types';
  import type { FolderApi } from 'tweakpane';

  let {
    label = $bindable(''),
    expanded = $bindable(true),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    targets = $bindable<string[]>([]),
    childEntries = {} as ChildEntries,
  }: {
    label?: string;
    expanded?: boolean;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    targets?: string[];
    childEntries?: ChildEntries;
  } = $props();

  const parentCtx = getContext<TpContext>('ic-tp');

  // Override context for sub-blades
  const ctx: TpContext = $state({ container: undefined });
  setContext('ic-tp', ctx);

  const bladeTargets = $derived(
    (Array.isArray(targets) ? targets : targets ? [targets] : []).filter((t: string) =>
      t.startsWith('blade-'),
    ),
  );

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

<!-- Sub-blade snippets -->
{#each bladeTargets as target (target)}
  {#each childEntries[target] ?? [] as child (child.id)}
    {@render child.snippet()}
  {/each}
{/each}
