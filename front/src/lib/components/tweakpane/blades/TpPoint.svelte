<!--
  TpPoint.svelte — 2D/3D/4D point input blade.
  Tweakpane auto-detects dimensionality from the value struct fields.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable<Record<string, number>>({ x: 0, y: 0 }),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanged,
  }: {
    label?: string;
    value?: Record<string, number>;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    valueChanged?: (data: { value: Record<string, number> }) => void;
  } = $props();

  function shallowEqual(a: Record<string, number>, b: Record<string, number>): boolean {
    for (const k in b) { if (a[k] !== b[k]) return false; }
    return true;
  }

  const ctx = getContext<TpContext>('ic-tp');
  let binding: BindingApi | undefined;
  const params = { value: { ...value } };

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    Object.assign(params.value, untrack(() => value));
    binding = container.addBinding(params, 'value', {
      label: label || undefined,
      index: bladeIndex,
    });

    binding.on('change', (ev) => {
      value = { ...ev.value };
      valueChanged?.({ value: { ...ev.value } });
    });

    return () => {
      binding?.dispose();
      binding = undefined;
    };
  });

  $effect(() => {
    const v = value;
    if (binding && !shallowEqual(params.value, v)) {
      Object.assign(params.value, v);
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
