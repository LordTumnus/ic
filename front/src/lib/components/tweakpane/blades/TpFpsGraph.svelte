<!--
  TpFpsGraph.svelte — FPS monitoring blade (plugin-essentials).
  Auto-updating: calls begin()/end() on each animation frame.
-->
<script lang="ts">
  import { getContext } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BladeApi } from 'tweakpane';

  let {
    label = $bindable(''),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
  }: {
    label?: string;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let blade: BladeApi | undefined;

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    const fpsGraph = container.addBlade({
      view: 'fpsgraph',
      label: label || undefined,
      index: bladeIndex,
    }) as BladeApi & { begin(): void; end(): void };

    blade = fpsGraph;

    // Auto-tick on each animation frame
    let rafId: number;
    function tick() {
      fpsGraph.begin();
      fpsGraph.end();
      rafId = requestAnimationFrame(tick);
    }
    rafId = requestAnimationFrame(tick);

    return () => {
      cancelAnimationFrame(rafId);
      blade?.dispose();
      blade = undefined;
    };
  });

  $effect(() => {
    if (blade) {
      blade.disabled = disabled;
      blade.hidden = hidden;
    }
  });
</script>
