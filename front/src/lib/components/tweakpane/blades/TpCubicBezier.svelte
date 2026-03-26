<!--
  TpCubicBezier.svelte — Bezier curve editor (plugin-essentials).
  Uses addBlade with view:'cubicbezier'. Value is [x1, y1, x2, y2].
  MATLAB sends {x1, y1, x2, y2} struct → converted to array for Tweakpane.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BladeApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable<{ x1: number; y1: number; x2: number; y2: number }>({
      x1: 0.25,
      y1: 0.1,
      x2: 0.25,
      y2: 1,
    }),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanged,
  }: {
    label?: string;
    value?: { x1: number; y1: number; x2: number; y2: number };
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    valueChanged?: (data: {
      value: { x1: number; y1: number; x2: number; y2: number };
    }) => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let blade: BladeApi | undefined;

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    const bezier = container.addBlade({
      view: 'cubicbezier',
      value: untrack(() => [value.x1, value.y1, value.x2, value.y2]),
      expanded: false,
      label: label || undefined,
      index: bladeIndex,
    } as Record<string, unknown>) as BladeApi & {
      value: unknown;
      on(event: string, handler: (ev: any) => void): void;
    };

    blade = bezier;

    bezier.on('change', (ev: { value: { x1: number; y1: number; x2: number; y2: number } }) => {
      const cb = ev.value;
      value = { x1: cb.x1, y1: cb.y1, x2: cb.x2, y2: cb.y2 };
      valueChanged?.({ value: { ...value } });
    });

    return () => {
      blade?.dispose();
      blade = undefined;
    };
  });

  // Sync MATLAB → Tweakpane
  $effect(() => {
    const v = value;
    if (!blade) return;
    const api = blade as BladeApi & { value: any };
    const current = api.value;
    if (
      current.x1 === v.x1 &&
      current.y1 === v.y1 &&
      current.x2 === v.x2 &&
      current.y2 === v.y2
    )
      return;
    const CubicBezierClass = current.constructor;
    api.value = new CubicBezierClass(v.x1, v.y1, v.x2, v.y2);
  });

  $effect(() => {
    const d = disabled;
    const h = hidden;
    if (blade) {
      blade.disabled = d;
      blade.hidden = h;
    }
  });
</script>
