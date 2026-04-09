<!--
  TpRing.svelte — Radial dial blade (plugin-camerakit).
  Circular ring control with tick marks. Continuous control pattern.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    id = '',
    label = $bindable(''),
    value = $bindable(0),
    min = $bindable(0),
    max = $bindable(360),
    step = $bindable(1),
    wide = $bindable(false),
    series = $bindable(0),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanging,
    valueChanged,
  }: {
    id?: string;
    label?: string;
    value?: number;
    min?: number;
    max?: number;
    step?: number;
    wide?: boolean;
    series?: number;
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
      view: 'cameraring',
      label: label || undefined,
      min,
      max,
      step,
      wide,
      series,
      index: bladeIndex,
    } as Record<string, unknown>);

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

  $effect(() => {
    const v = value;
    if (binding && params.value !== v) {
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
