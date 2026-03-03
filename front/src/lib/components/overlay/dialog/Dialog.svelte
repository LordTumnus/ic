<!--
  Dialog.svelte — Modal overlay with title, body content, and action buttons.

  Always in the DOM; the `open` prop toggles visibility via CSS transitions.
  Added via addOverlay() so it renders at the container's root level
  (the "overlay" snippet target). position: absolute covers the parent container.
  Targets: "body" (main content), "footer" (custom footer replaces default buttons).
  z-index 8000 (below Toast at 9000).
-->
<script lang="ts">
  import type { Snippets } from '$lib/types';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    title = $bindable(''),
    open = $bindable(false),
    size = $bindable('md'),
    closable = $bindable(true),
    closeOnBackdropClick = $bindable(true),
    submitLabel = $bindable('OK'),
    cancelLabel = $bindable('Cancel'),
    snippets = { body: [], footer: [] } as Snippets,
    submitted,
    closed,
  }: {
    title?: string;
    open?: boolean;
    size?: string;
    closable?: boolean;
    closeOnBackdropClick?: boolean;
    submitLabel?: string;
    cancelLabel?: string;
    snippets?: Snippets;
    submitted?: (data?: unknown) => void;
    closed?: (data?: unknown) => void;
  } = $props();

  let contentEl: HTMLDivElement;

  const closeSvg = resolveIcon('x', 14);

  const hasCustomFooter = $derived((snippets.footer?.length ?? 0) > 0);
  const showSubmit = $derived(!hasCustomFooter && submitLabel !== '');
  const showCancel = $derived(!hasCustomFooter && cancelLabel !== '');
  const showDefaultFooter = $derived(showSubmit || showCancel);

  // Focus the dialog content when opened
  $effect(() => {
    if (open) {
      requestAnimationFrame(() => {
        contentEl?.focus();
      });
    }
  });

  function handleClose() {
    open = false;
    closed?.({});
  }

  function handleSubmit() {
    open = false;
    submitted?.({});
  }

  function handleBackdropPointerDown(e: PointerEvent) {
    if (closeOnBackdropClick && e.target === e.currentTarget) {
      handleClose();
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && closable && open) {
      e.preventDefault();
      e.stopPropagation();
      handleClose();
    }
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-dialog"
  class:ic-dialog--open={open}
  onkeydown={handleKeydown}
>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-dialog__backdrop"
    onpointerdown={handleBackdropPointerDown}
  >
    <div
      bind:this={contentEl}
      class="ic-dialog__content"
      class:ic-dialog__content--sm={size === 'sm'}
      class:ic-dialog__content--md={size === 'md'}
      class:ic-dialog__content--lg={size === 'lg'}
      class:ic-dialog__content--xl={size === 'xl'}
      role="dialog"
      aria-modal="true"
      aria-label={title || 'Dialog'}
      tabindex="-1"
    >
      <!-- Header -->
      {#if title || closable}
        <div class="ic-dialog__header">
          {#if title}
            <h2 class="ic-dialog__title">{title}</h2>
          {/if}
          {#if closable}
            <button
              class="ic-dialog__close"
              onclick={handleClose}
              aria-label="Close dialog"
            >
              {@html closeSvg}
            </button>
          {/if}
        </div>
      {/if}

      <!-- Body -->
      <div class="ic-dialog__body">
        {#each snippets.body ?? [] as child (child)}
          {@render child()}
        {/each}
      </div>

      <!-- Footer: custom children OR default buttons -->
      {#if hasCustomFooter}
        <div class="ic-dialog__footer">
          {#each snippets.footer ?? [] as child (child)}
            {@render child()}
          {/each}
        </div>
      {:else if showDefaultFooter}
        <div class="ic-dialog__footer">
          {#if showCancel}
            <button
              class="ic-dialog__btn ic-dialog__btn--cancel"
              onclick={handleClose}
            >
              {cancelLabel}
            </button>
          {/if}
          {#if showSubmit}
            <button
              class="ic-dialog__btn ic-dialog__btn--submit"
              onclick={handleSubmit}
            >
              {submitLabel}
            </button>
          {/if}
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  /* ===== WRAPPER ===== */

  .ic-dialog {
    position: absolute;
    inset: 0;
    z-index: 8000;
    visibility: hidden;
    pointer-events: none;
  }

  .ic-dialog--open {
    visibility: visible;
    pointer-events: auto;
  }

  /* ===== BACKDROP ===== */

  .ic-dialog__backdrop {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: rgba(0, 0, 0, 0.4);
    opacity: 0;
    transition: opacity 0.2s ease;
    padding: 24px;
  }

  .ic-dialog--open .ic-dialog__backdrop {
    opacity: 1;
  }

  /* ===== CONTENT ===== */

  .ic-dialog__content {
    display: flex;
    flex-direction: column;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow:
      0 8px 32px rgba(0, 0, 0, 0.28),
      0 2px 8px rgba(0, 0, 0, 0.12),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
    width: 100%;
    max-height: calc(100% - 48px);
    outline: none;
    overflow: clip;
    transform: scale(0.95);
    opacity: 0;
    transition: transform 0.2s ease, opacity 0.2s ease;
  }

  .ic-dialog--open .ic-dialog__content {
    transform: scale(1);
    opacity: 1;
  }

  /* ===== SIZES ===== */

  .ic-dialog__content--sm { max-width: 400px; }
  .ic-dialog__content--md { max-width: 560px; }
  .ic-dialog__content--lg { max-width: 720px; }
  .ic-dialog__content--xl { max-width: 900px; }

  /* ===== HEADER ===== */

  .ic-dialog__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    border-bottom: 1px solid var(--ic-border);
    flex-shrink: 0;
  }

  .ic-dialog__title {
    margin: 0;
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ic-foreground);
    line-height: 1.4;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ic-dialog__close {
    all: unset;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 24px;
    height: 24px;
    border-radius: 2px;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    margin-left: auto;
  }

  .ic-dialog__close:hover {
    color: var(--ic-foreground);
    background: rgba(0, 0, 0, 0.08);
  }

  /* ===== BODY ===== */

  .ic-dialog__body {
    flex: 1 1 auto;
    padding: 16px;
    overflow: auto;
    min-height: 0;
  }

  /* ===== FOOTER ===== */

  .ic-dialog__footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 8px;
    padding: 10px 16px;
    border-top: 1px solid var(--ic-border);
    flex-shrink: 0;
  }

  /* ===== DEFAULT BUTTONS ===== */

  .ic-dialog__btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.375rem 0.75rem;
    border: 1.5px solid transparent;
    border-radius: 2px;
    font-family: inherit;
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    outline: none;
    transition: all 0.15s ease;
  }

  .ic-dialog__btn--cancel {
    background-color: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    border-color: var(--ic-border);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.15),
      inset 0 1px 0 rgba(255, 255, 255, 0.08);
  }

  .ic-dialog__btn--cancel:hover {
    background-color: var(--ic-muted);
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.08);
  }

  .ic-dialog__btn--submit {
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
    border-color: transparent;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-dialog__btn--submit:hover {
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }
</style>
