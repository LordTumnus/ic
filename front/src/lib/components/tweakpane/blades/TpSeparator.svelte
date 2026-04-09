<!--
  TpSeparator.svelte — Visual divider blade.
-->
<script lang="ts">
  import { getContext } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BladeApi } from 'tweakpane';

  let {
    id = '',
    bladeIndex = $bindable(0),
  }: {
    id?: string;
    bladeIndex?: number;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let blade: BladeApi | undefined;

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    blade = container.addBlade({
      view: 'separator',
      index: bladeIndex,
    });

    return () => {
      blade?.dispose();
      blade = undefined;
    };
  });
</script>
