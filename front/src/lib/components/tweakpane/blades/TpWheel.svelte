<!--
  TpWheel.svelte — Jog wheel blade (plugin-camerakit).
  Fine-grained unbounded adjustment via scroll-wheel interaction.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable(0),
    amount = $bindable(1),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanging,
    valueChanged,
  }: {
    label?: string;
    value?: number;
    amount?: number;
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
      view: 'camerawheel',
      label: label || undefined,
      amount,
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
