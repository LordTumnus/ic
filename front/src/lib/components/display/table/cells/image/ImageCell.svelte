<script lang="ts">
  import type { ImageConfig } from '$lib/utils/table-utils';
  import type { AssetData } from '$lib/utils/asset-cache';
  import { resolveAssetAsDataUri } from '$lib/utils/asset-cache';

  let {
    value,
    config = {} as Partial<ImageConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<ImageConfig>;
    style?: string;
  } = $props();

  const popupWidth = $derived(config.popupWidth ?? 200);
  const popupHeight = $derived(config.popupHeight ?? 150);
  const objectFit = $derived(config.objectFit ?? 'contain');

  // Resolve cell value → data URI
  const imgSrc = $derived.by((): string => {
    if (!value) return '';
    if (typeof value === 'object' && value !== null && 'hash' in (value as Record<string, unknown>)) {
      return resolveAssetAsDataUri(value as AssetData);
    }
    return '';
  });

  const hasImage = $derived(imgSrc !== '');

  let thumbEl = $state<HTMLElement>(null!);
  let showPopup = $state(false);
  let popupX = $state(0);
  let popupY = $state(0);

  function onenter() {
    if (!hasImage || !thumbEl) return;
    const rect = thumbEl.getBoundingClientRect();
    // Center horizontally below the thumbnail
    let x = rect.left + rect.width / 2 - popupWidth / 2;
    let y = rect.bottom + 4;
    // Flip above if would overflow viewport bottom
    if (y + popupHeight > window.innerHeight - 8) {
      y = rect.top - popupHeight - 4;
    }
    // Clamp horizontal
    if (x < 8) x = 8;
    if (x + popupWidth > window.innerWidth - 8) {
      x = window.innerWidth - popupWidth - 8;
    }
    popupX = x;
    popupY = y;
    showPopup = true;
  }

  function onleave() {
    showPopup = false;
  }

  // Image column doesn't tint cell background
  $effect(() => { style = ''; });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-tbl-cell-img"
  bind:this={thumbEl}
  onpointerenter={onenter}
  onpointerleave={onleave}
>
  {#if hasImage}
    <img class="ic-tbl-cell-img__thumb" src={imgSrc} alt="" />
  {:else}
    <span class="ic-tbl-cell-img__empty">
      <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24"
        fill="none" stroke="currentColor" stroke-width="1.5"
        stroke-linecap="round" stroke-linejoin="round">
        <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
        <circle cx="8.5" cy="8.5" r="1.5" />
        <polyline points="21 15 16 10 5 21" />
      </svg>
    </span>
  {/if}
</div>

{#if showPopup && hasImage}
  <div
    class="ic-tbl-cell-img__popup"
    style="left: {popupX}px; top: {popupY}px; width: {popupWidth}px; height: {popupHeight}px;"
  >
    <img
      class="ic-tbl-cell-img__popup-img"
      src={imgSrc}
      alt=""
      style="object-fit: {objectFit};"
    />
  </div>
{/if}

<style>
  .ic-tbl-cell-img {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    cursor: default;
  }

  /* Inline thumbnail */
  .ic-tbl-cell-img__thumb {
    width: 20px;
    height: 20px;
    object-fit: cover;
    border-radius: 2px;
    border: 1px solid var(--ic-border);
    background: var(--ic-secondary);
    display: block;
  }

  /* Empty placeholder icon */
  .ic-tbl-cell-img__empty {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    color: var(--ic-muted-foreground);
    opacity: 0.4;
  }

  /* Hover preview popup */
  .ic-tbl-cell-img__popup {
    position: fixed;
    z-index: 100;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
    overflow: hidden;
    pointer-events: none;
  }

  .ic-tbl-cell-img__popup-img {
    display: block;
    width: 100%;
    height: 100%;
  }
</style>
