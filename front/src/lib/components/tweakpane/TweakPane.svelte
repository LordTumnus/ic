<!--
  TweakPane.svelte — Root Tweakpane container.

  Creates a Tweakpane Pane instance and sets Svelte context ('ic-tp')
  so child blade components can find it. Child snippets are rendered
  below; each blade creates its own Tweakpane binding imperatively.

  Context is a reactive $state object so children's $effects re-run
  when the Pane becomes available (parent effects run after children's).
-->
<script lang="ts">
  import { Pane, type FolderApi, type TabPageApi } from 'tweakpane';
  import * as EssentialsPlugin from '@tweakpane/plugin-essentials';
  import * as CamerakitPlugin from '@tweakpane/plugin-camerakit';
  import * as RotationPlugin from '@0b5vr/tweakpane-plugin-rotation';
  import * as TextareaPlugin from '@pangenerator/tweakpane-textarea-plugin';
  import { setContext } from 'svelte';
  import type { ChildEntries } from '$lib/types';
  import { applyIcTheme } from './tp-theme';

  export interface TpContext {
    container: Pane | FolderApi | TabPageApi | undefined;
  }

  let {
    title = $bindable(''),
    expanded = $bindable(true),
    targets = $bindable<string[]>([]),
    childEntries = {} as ChildEntries,
  }: {
    title?: string;
    expanded?: boolean;
    targets?: string[];
    childEntries?: ChildEntries;
  } = $props();

  let containerEl: HTMLDivElement;

  // Reactive context: children depend on ctx.container in their $effects
  const ctx: TpContext = $state({ container: undefined });
  setContext('ic-tp', ctx);

  const bladeTargets = $derived(
    Array.isArray(targets) ? targets.filter((t) => t.startsWith('blade-')) : [],
  );

  $effect(() => {
    if (!containerEl) return;

    const pane = new Pane({
      container: containerEl,
      title: title || undefined,
      expanded,
    });
    pane.registerPlugin(EssentialsPlugin);
    pane.registerPlugin(CamerakitPlugin);
    pane.registerPlugin(RotationPlugin);
    pane.registerPlugin(TextareaPlugin);
    applyIcTheme(containerEl);

    ctx.container = pane;

    return () => {
      ctx.container = undefined;
      pane.dispose();
    };
  });

  // Sync prop changes to Pane
  $effect(() => {
    const pane = ctx.container;
    if (pane && 'expanded' in pane) {
      (pane as Pane).expanded = expanded;
    }
  });
</script>

<div bind:this={containerEl} class="ic-tp"></div>

<!-- Child blade snippets — they render no visible DOM, just manage Tweakpane bindings -->
{#each bladeTargets as target (target)}
  {#each childEntries[target] ?? [] as child (child.id)}
    {@render child.snippet()}
  {/each}
{/each}

<style>
  .ic-tp {
    width: 100%;
  }
</style>
