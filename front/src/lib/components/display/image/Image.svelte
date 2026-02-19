<script lang="ts">
  import logger from '$lib/core/logger';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import { resolveImageSource, type ImageSource } from '$lib/utils/icons';

  let {
    source = $bindable<ImageSource>(null),
    width = $bindable<CssSize>('auto'),
    height = $bindable<CssSize>('auto'),
    objectFit = $bindable('contain'),
    borderRadius = $bindable<CssSize>(2),
    opacity = $bindable(1),
    clicked,
    loaded,
    error: errorEvent,
  }: {
    source?: ImageSource;
    width?: CssSize;
    height?: CssSize;
    objectFit?: string;
    borderRadius?: CssSize;
    opacity?: number;
    clicked?: (data?: unknown) => void;
    loaded?: (data?: unknown) => void;
    error?: (data?: unknown) => void;
  } = $props();

  // Resolve AssetData → data URI for <img src>
  const imgSrc = $derived(resolveImageSource(source));

  let imgError = $state(false);

  // Reset error when source changes
  $effect.pre(() => {
    void source;
    imgError = false;
  });

  function handleLoad() {
    loaded?.({ source });
  }

  function handleError() {
    logger.warn('Image', 'failed to load');
    imgError = true;
    errorEvent?.({ source });
  }
</script>

{#snippet imageContent()}
  {#if imgSrc && !imgError}
    <img
      class="ic-image__img"
      src={imgSrc}
      alt=""
      style:object-fit={objectFit}
      style:border-radius={toSize(borderRadius)}
      style:opacity={opacity}
      onload={handleLoad}
      onerror={handleError}
    />
  {/if}

  {#if !imgSrc || imgError}
    <div class="ic-image__fallback" style:border-radius={toSize(borderRadius)}>
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
        fill="none" stroke="currentColor" stroke-width="1.5"
        stroke-linecap="round" stroke-linejoin="round">
        {#if imgError}
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
          <line x1="3" y1="3" x2="21" y2="21" />
        {:else}
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
          <circle cx="8.5" cy="8.5" r="1.5" />
          <polyline points="21 15 16 10 5 21" />
        {/if}
      </svg>
    </div>
  {/if}
{/snippet}

{#if clicked}
  <button
    type="button"
    class="ic-image ic-image--clickable"
    style:width={toSize(width)}
    style:height={toSize(height)}
    style:border-radius={toSize(borderRadius)}
    onclick={() => clicked?.({ source })}
  >
    {@render imageContent()}
  </button>
{:else}
  <div
    class="ic-image"
    style:width={toSize(width)}
    style:height={toSize(height)}
    style:border-radius={toSize(borderRadius)}
  >
    {@render imageContent()}
  </div>
{/if}

<style>
  .ic-image {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    background-color: var(--ic-secondary);
    border: 1px solid var(--ic-border);
    padding: 0;
    font: inherit;
  }

  .ic-image--clickable {
    cursor: pointer;
  }
  .ic-image--clickable:focus-visible {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-image__img {
    display: block;
    width: 100%;
    height: 100%;
  }

  .ic-image__fallback {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: var(--ic-secondary);
    color: var(--ic-muted-foreground);
  }
</style>
