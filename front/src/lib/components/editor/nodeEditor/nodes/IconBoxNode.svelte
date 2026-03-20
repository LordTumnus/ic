<!--
  IconBoxNode.svelte — Box with a Lucide icon centered and label below.
  HTML-based rounded rect with Icon component.
  Input port on left, output port on right.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';
  import Icon from '$lib/components/display/icon/Icon.svelte';
  import { resolveImageSource } from '$lib/utils/icons';

  type IconBoxData = {
    label: string;
    icon: any;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type IconBoxNodeType = Node<IconBoxData, 'ic.node.IconBox'>;

  let { data, selected, dragging }: NodeProps<IconBoxNodeType> = $props();

  let hovered = $state(false);

  /** True when the icon is a non-SVG raster asset (PNG, JPG, etc.) */
  const isImageAsset = $derived(
    data.icon && typeof data.icon === 'object' && data.icon.hash &&
    data.icon.mime && !data.icon.mime.includes('svg'),
  );
  const imageSrc = $derived(isImageAsset ? resolveImageSource(data.icon) : '');

  const bgColor = $derived(data.backgroundColor || 'var(--ic-muted)');
  const borderColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : data.outlineColor || 'var(--ic-border)',
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-iconbox"
  class:ic-ne-iconbox--hovered={hovered && !selected && !dragging}
  class:ic-ne-iconbox--selected={selected}
  class:ic-ne-iconbox--dragging={dragging}
  class:ic-ne-iconbox--disabled={data.disabled}
  style:background-color={bgColor}
  style:border-color={borderColor}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <div class="ic-ne-iconbox__icon">
    {#if isImageAsset}
      <img class="ic-ne-iconbox__img" src={imageSrc} alt="" width="28" height="28" />
    {:else}
      <Icon source={data.icon} size={24} />
    {/if}
  </div>
  <div class="ic-ne-iconbox__label">
    <InlineEdit
      value={data.label}
      className="ic-ne-iconbox__label-edit"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>

  <!-- Input handle: left midpoint -->
  {#if data.inputs?.[0]}
    <PortHandle type="target" position={Position.Left} id={data.inputs[0].name} variant="dot" />
  {/if}

  <!-- Output handle: right midpoint -->
  {#if data.outputs?.[0]}
    <PortHandle type="source" position={Position.Right} id={data.outputs[0].name} variant="dot" />
  {/if}
</div>

<style>
  .ic-ne-iconbox {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    width: 64px;
    height: 64px;
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    font-family: var(--ic-font-family);
    gap: 4px;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-iconbox--hovered {
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-iconbox--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-iconbox--dragging {
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.25);
  }

  .ic-ne-iconbox--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-iconbox__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--ic-foreground);
  }

  .ic-ne-iconbox__img {
    object-fit: contain;
    border-radius: 2px;
    image-rendering: pixelated;
  }

  .ic-ne-iconbox__label {
    font-size: 9px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-align: center;
    max-width: 58px;
    overflow: clip;
  }

  .ic-ne-iconbox__label :global(.ic-ne-iconbox__label-edit) {
    font-family: var(--ic-font-family);
    font-size: 9px;
    color: var(--ic-muted-foreground);
  }
</style>
