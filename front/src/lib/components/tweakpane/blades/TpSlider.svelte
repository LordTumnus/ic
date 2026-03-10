<!--
  TpSlider.svelte — Numeric slider blade.
  Zero DOM: creates a Tweakpane binding on the parent Pane via context.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable(0),
    min = $bindable(0),
    max = $bindable(100),
    step = $bindable(1),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanging,
    valueChanged,
  }: {
    label?: string;
    value?: number;
    min?: number;
    max?: number;
    step?: number;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    valueChanging?: (data: { value: number }) => void;
    valueChanged?: (data: { value: number }) => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let binding: BindingApi | undefined;
  const params = { value };

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    params.value = untrack(() => value);
    binding = container.addBinding(params, 'value', {
      label: label || undefined,
      min,
      max,
      step,
      index: bladeIndex,
    });

    binding.on('change', (ev) => {
      value = ev.value;
      if (ev.last) {
        valueChanged?.({ value: ev.value });
      } else {
        valueChanging?.({ value: ev.value });
      }
    });

    return () => {
      binding?.dispose();
      binding = undefined;
    };
  });

  // Sync MATLAB → Tweakpane
  $effect(() => {
    if (binding && params.value !== value) {
      params.value = value;
      binding.refresh();
    }
  });

  // Sync blade meta props
  $effect(() => {
    if (binding) {
      binding.disabled = disabled;
      binding.hidden = hidden;
    }
  });
</script>
