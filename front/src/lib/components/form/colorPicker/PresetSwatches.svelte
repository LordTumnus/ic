<script lang="ts">
  let {
    presets = [],
    onselect,
  }: {
    presets?: string[];
    onselect?: (color: string) => void;
  } = $props();
</script>

{#if presets.length > 0}
  <div class="ic-cp-presets">
    {#each presets as color (color)}
      <button
        class="ic-cp-presets__swatch"
        style="background-color: {color}"
        onclick={() => onselect?.(color)}
        aria-label="Select color {color}"
      ></button>
    {/each}
  </div>
{/if}

<style>
  .ic-cp-presets {
    display: flex;
    flex-wrap: wrap;
    gap: 3px;
    padding-top: 6px;
    border-top: 1px solid var(--ic-border);
  }

  .ic-cp-presets__swatch {
    width: 16px;
    height: 16px;
    border-radius: 2px;
    border: 1px solid rgba(0, 0, 0, 0.1);
    cursor: pointer;
    padding: 0;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1);
    transition: box-shadow 0.1s ease;
    outline: none;
  }

  .ic-cp-presets__swatch:hover {
    box-shadow:
      0 1px 4px rgba(0, 0, 0, 0.3),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
  }

  .ic-cp-presets__swatch:focus-visible {
    border-color: var(--ic-primary);
  }
</style>
