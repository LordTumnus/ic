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
  import { setContext, getAllContexts } from 'svelte';
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
    (Array.isArray(targets) ? targets : targets ? [targets] : []).filter((t: string) =>
      t.startsWith('blade-'),
    ),
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

  // Capture context so attachable blades can inherit it via mount()
  const svelteCtx = getAllContexts();

  // Attach/detach blade children into a hidden mount point
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

    // Detach removed blades
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

<div bind:this={containerEl} class="ic-tp"></div>

<!-- Hidden mount point for attachable blade components (no visible DOM) -->
<div bind:this={mountEl} style="display: none"></div>

<style>
  .ic-tp {
    width: 100%;
  }
</style>
