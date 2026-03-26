<!--
  TpList.svelte — Dropdown select blade.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable(''),
    items = $bindable<string[]>([]),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanged,
  }: {
    label?: string;
    value?: string;
    items?: string[];
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    valueChanged?: (data: { value: string }) => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let binding: BindingApi | undefined;
  const params = { value };

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    // Build options object: { label: value, ... }
    const options: Record<string, string> = {};
    for (const item of items) {
      options[item] = item;
    }

    params.value = untrack(() => value);
    binding = container.addBinding(params, 'value', {
      label: label || undefined,
      options,
      index: bladeIndex,
    });

    binding.on('change', (ev) => {
      value = ev.value;
      valueChanged?.({ value: ev.value });
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
