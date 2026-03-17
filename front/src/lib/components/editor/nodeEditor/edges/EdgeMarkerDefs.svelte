<!--
  EdgeMarkerDefs.svelte — Per-edge SVG marker definitions.

  Renders <defs> with arrow/diamond/circle markers whose fill matches the
  edge's stroke color. Each marker gets a unique ID based on the edge ID,
  so multiple edges can have different-colored markers simultaneously.

  Chromium 104 does not support `context-stroke`, so we bake the color
  into each marker definition instead.
-->
<script lang="ts">
  let {
    edgeId,
    color,
    startArrow,
    endArrow,
  }: {
    edgeId: string;
    color: string;
    startArrow?: string;
    endArrow?: string;
  } = $props();

  const needsArrow = $derived(startArrow === 'arrow' || endArrow === 'arrow');
  const needsDiamond = $derived(startArrow === 'diamond' || endArrow === 'diamond');
  const needsCircle = $derived(startArrow === 'circle' || endArrow === 'circle');
</script>

{#if needsArrow || needsDiamond || needsCircle}
  <defs>
    {#if needsArrow}
      <marker
        id="ic-marker-arrow-{edgeId}"
        viewBox="0 0 10 10"
        refX="10"
        refY="5"
        markerWidth="8"
        markerHeight="8"
        orient="auto-start-reverse"
      >
        <path d="M0 0 L10 5 L0 10 Z" fill={color} />
      </marker>
    {/if}
    {#if needsDiamond}
      <marker
        id="ic-marker-diamond-{edgeId}"
        viewBox="0 0 10 10"
        refX="5"
        refY="5"
        markerWidth="10"
        markerHeight="10"
        orient="auto-start-reverse"
      >
        <path d="M5 0 L10 5 L5 10 L0 5 Z" fill={color} />
      </marker>
    {/if}
    {#if needsCircle}
      <marker
        id="ic-marker-circle-{edgeId}"
        viewBox="0 0 10 10"
        refX="5"
        refY="5"
        markerWidth="8"
        markerHeight="8"
        orient="auto"
      >
        <circle cx="5" cy="5" r="4" fill={color} />
      </marker>
    {/if}
  </defs>
{/if}
