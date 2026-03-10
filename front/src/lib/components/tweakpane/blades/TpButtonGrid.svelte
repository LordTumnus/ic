<!--
  TpButtonGrid.svelte — Grid of buttons (plugin-essentials).
  Uses addBlade with view:'buttongrid' and a cells callback.
-->
<script lang="ts">
  import { getContext } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BladeApi } from 'tweakpane';

  let {
    label = $bindable(''),
    items = $bindable<string[]>([]),
    columns = $bindable(2),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    clicked,
  }: {
    label?: string;
    items?: string[];
    columns?: number;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    clicked?: (data: { value: string }) => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let blade: BladeApi | undefined;

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    const rows = Math.ceil(items.length / columns);

    const buttonGrid = container.addBlade({
      view: 'buttongrid',
      label: label || undefined,
      size: [columns, rows],
      cells: (x: number, y: number) => {
        const idx = y * columns + x;
        return { title: idx < items.length ? items[idx] : '' };
      },
      index: bladeIndex,
    } as Record<string, unknown>) as BladeApi & {
      on(event: 'click', handler: (ev: { index: [number, number] }) => void): void;
    };

    blade = buttonGrid;

    buttonGrid.on('click', (ev) => {
      const [x, y] = ev.index;
      const idx = y * columns + x;
      if (idx < items.length) {
        clicked?.({ value: items[idx] });
      }
    });

    return () => {
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
