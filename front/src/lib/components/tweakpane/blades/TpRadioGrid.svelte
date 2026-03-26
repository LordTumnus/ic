<!--
  TpRadioGrid.svelte — Grid of radio buttons (plugin-essentials).
  Uses addBinding with view:'radiogrid' and a cells callback.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable(''),
    items = $bindable<string[]>([]),
    columns = $bindable(2),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanged,
  }: {
    label?: string;
    value?: string;
    items?: string[];
    columns?: number;
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

    const rows = Math.ceil(items.length / columns);

    params.value = untrack(() => value);
    binding = container.addBinding(params, 'value', {
      label: label || undefined,
      view: 'radiogrid',
      groupName: label || 'radio',
      size: [columns, rows],
      cells: (x: number, y: number) => {
        const idx = y * columns + x;
        const title = idx < items.length ? items[idx] : '';
        return { title, value: title };
      },
      index: bladeIndex,
    } as Record<string, unknown>);

    binding.on('change', (ev) => {
      value = ev.value as string;
      valueChanged?.({ value: ev.value as string });
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
