<!--
  TpImage.svelte — Read-only image display blade (custom).
  No Tweakpane plugin — uses a separator blade as a DOM anchor,
  then replaces its content with a styled image element.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BladeApi } from 'tweakpane';

  let {
    label = $bindable(''),
    source = $bindable<string | { hash: string; mime: string; data: string } | null>(null),
    height = $bindable(100),
    objectFit = $bindable<'contain' | 'cover' | 'fill'>('contain'),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    clicked,
  }: {
    label?: string;
    source?: string | { hash: string; mime: string; data: string } | null;
    height?: number;
    objectFit?: 'contain' | 'cover' | 'fill';
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    clicked?: (data: Record<string, never>) => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let blade: BladeApi | undefined = $state();
  let img: HTMLImageElement | undefined = $state();
  let wrapper: HTMLDivElement | undefined = $state();

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    // Read label directly (not untracked) so label changes recreate the DOM,
    // consistent with how all other blades handle label as a setup dependency.
    const currentLabel = label;

    // Use a separator blade for proper ordering in the Tweakpane layout
    const sep = container.addBlade({
      view: 'separator',
      index: bladeIndex,
    });
    blade = sep;

    // Replace separator content with image display
    const el = sep.element;
    el.innerHTML = '';
    el.style.padding = '0';

    const w = document.createElement('div');
    w.style.display = 'flex';
    w.style.alignItems = 'center';
    w.style.gap = '4px';
    w.style.padding = '2px 4px';

    // Label
    if (currentLabel) {
      const lbl = document.createElement('div');
      lbl.className = 'tp-lblv_l';
      lbl.textContent = currentLabel;
      lbl.style.flexShrink = '0';
      w.appendChild(lbl);
    }

    // Image element
    const imgEl = document.createElement('img');
    imgEl.style.width = '100%';
    imgEl.style.height = `${untrack(() => height)}px`;
    imgEl.style.objectFit = untrack(() => objectFit);
    imgEl.style.borderRadius = '2px';
    imgEl.style.cursor = 'pointer';
    imgEl.style.display = 'block';
    imgEl.draggable = false;
    imgEl.onclick = () => clicked?.({} as Record<string, never>);

    const imgContainer = document.createElement('div');
    imgContainer.style.flex = '1';
    imgContainer.style.minWidth = '0';
    imgContainer.appendChild(imgEl);
    w.appendChild(imgContainer);

    el.appendChild(w);
    img = imgEl;
    wrapper = w;

    return () => {
      blade?.dispose();
      blade = undefined;
      img = undefined;
      wrapper = undefined;
    };
  });

  // Sync source → img.src
  $effect(() => {
    if (!img) return;
    if (source && typeof source === 'object' && 'data' in source) {
      img.src = `data:${source.mime};base64,${source.data}`;
    } else if (typeof source === 'string' && source) {
      img.src = source;
    } else {
      img.src = '';
    }
  });

  // Sync height / objectFit
  $effect(() => {
    if (img) {
      img.style.height = `${height}px`;
      img.style.objectFit = objectFit;
    }
  });

  // Sync disabled / hidden
  $effect(() => {
    if (blade) {
      blade.hidden = hidden;
    }
    if (wrapper) {
      wrapper.style.opacity = disabled ? '0.5' : '1';
      wrapper.style.pointerEvents = disabled ? 'none' : 'auto';
    }
  });
</script>
