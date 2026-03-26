<!--
  TpMonitor.svelte — Read-only value display blade.
  MATLAB pushes values via the reactive `value` prop. Tweakpane renders
  as text or a scrolling graph.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable<number | string | boolean>(0),
    view = $bindable<'text' | 'graph'>('text'),
    graphMin = $bindable(-1),
    graphMax = $bindable(1),
    bufferSize = $bindable(64),
    interval = $bindable(200),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
  }: {
    label?: string;
    value?: number | string | boolean;
    view?: 'text' | 'graph';
    graphMin?: number;
    graphMax?: number;
    bufferSize?: number;
    interval?: number;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let binding: BindingApi | undefined;
  const params = { value };

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    params.value = untrack(() => value);
    const opts: Record<string, unknown> = {
      label: label || undefined,
      readonly: true,
      index: bladeIndex,
      bufferSize,
      interval,
    };

    if (view === 'graph') {
      opts.view = 'graph';
      opts.min = graphMin;
      opts.max = graphMax;
    }

    binding = container.addBinding(params, 'value', opts);

    return () => {
      binding?.dispose();
      binding = undefined;
    };
  });

  // Push MATLAB value updates to Tweakpane
  $effect(() => {
    const v = value;
    if (binding) {
      params.value = v;
      binding.refresh();
    }
  });

  $effect(() => {
    const d = disabled;
    const h = hidden;
    if (binding) {
      binding.disabled = d;
      binding.hidden = h;
    }
  });
</script>
