<!--
  TpSlider.svelte — Numeric slider blade.
  Zero DOM: creates a Tweakpane binding on the parent Pane via context.
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
    max = $bindable(100),
    step = $bindable(1),
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

  // Sync MATLAB → Tweakpane (read value before guard so it's always tracked)
  $effect(() => {
    const v = value;
    if (binding && params.value !== v) {
      params.value = v;
      binding.refresh();
    }
  });

  // Sync blade meta props (read props before guard so they're always tracked)
  $effect(() => {
    const d = disabled;
    const h = hidden;
    if (binding) {
      binding.disabled = d;
      binding.hidden = h;
    }
  });
</script>
