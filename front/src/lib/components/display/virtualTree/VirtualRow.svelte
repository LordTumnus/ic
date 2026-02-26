<script lang="ts">
  import { resolveIcon } from '$lib/utils/icons';
  import type { FlatRow } from '$lib/utils/virtual-tree';
  import { highlightLabel } from '$lib/utils/filter-tree-utils';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import ContextMenu from '$lib/components/shared/ContextMenu.svelte';

  const ICON_SIZES: Record<string, number> = { sm: 10, md: 12, lg: 14 };
  const INDENT_REM: Record<string, number> = { sm: 1, md: 1.25, lg: 1.5 };
  const FOLDER_SIZES: Record<string, number> = { sm: 12, md: 14, lg: 16 };

  // --- Props ---
  let {
    row,
    size = 'md',
    selectable = true,
    disabled = false,
    showLine = false,
    expandedKeys,
    loadingKeys,
    isItemSelected,
    atMaxSelections = false,
    highlightRegex = null as RegExp | null,
    leafContextMenu = [] as ContextMenuEntry[],
    folderContextMenu = [] as ContextMenuEntry[],
    ontoggle,
    onexpandchange,
    oncontextmenuaction,
  }: {
    row: FlatRow;
    size?: string;
    selectable?: boolean;
    disabled?: boolean;
    showLine?: boolean;
    expandedKeys: Set<string>;
    loadingKeys: Set<string>;
    isItemSelected: (key: string) => boolean;
    atMaxSelections?: boolean;
    highlightRegex?: RegExp | null;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    ontoggle: (key: string) => void;
    onexpandchange: (key: string, expanded: boolean) => void;
    oncontextmenuaction?: (nodeKey: string, nodeType: 'leaf' | 'folder', itemKey: string) => void;
  } = $props();

  const node = $derived(row.node);
  const isFolder = $derived(node.isFolder);
  const isExpanded = $derived(expandedKeys.has(node.key));
  const isLoading = $derived(loadingKeys.has(node.key));

  // Highlight segments
  const labelSegments = $derived(
    highlightRegex ? highlightLabel(node.name, highlightRegex) : null
  );

  // Folder icons
  const folderSvg = $derived(resolveIcon('folder', FOLDER_SIZES[size] ?? 14));
  const folderOpenSvg = $derived(resolveIcon('folder-open', FOLDER_SIZES[size] ?? 14));

  // --- Handlers ---
  function handleFolderClick(e: MouseEvent) {
    e.stopPropagation();
    onexpandchange(node.key, !isExpanded);
  }

  function handleRowClick() {
    if (disabled || row.isPlaceholder) return;
    if (isFolder) {
      onexpandchange(node.key, !isExpanded);
    } else if (selectable) {
      if (atMaxSelections && !isItemSelected(node.key)) return;
      ontoggle(node.key);
    }
  }

  // --- Context menu ---
  let ctxMenu = $state<{ entries: ContextMenuEntry[]; x: number; y: number } | null>(null);

  function handleContextMenu(e: MouseEvent) {
    const entries = isFolder ? folderContextMenu : leafContextMenu;
    if (!entries?.length) return;
    e.preventDefault();
    e.stopPropagation();
    ctxMenu = { entries, x: e.clientX, y: e.clientY };
  }

  function handleCtxAction(key: string) {
    oncontextmenuaction?.(node.key, isFolder ? 'folder' : 'leaf', key);
    ctxMenu = null;
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<!-- svelte-ignore a11y_click_events_have_key_events -->
{#if row.isPlaceholder}
  <div
    class="ic-tn__row ic-vr--placeholder"
    style="padding-left: {showLine ? 0 : row.depth * INDENT_REM[size ?? 'md']}rem"
  >
    {#if showLine}
      <span class="ic-tn__guides">
        {#each row.parentLines as showPipe, pi (pi)}
          <span
            class="ic-tn__guide"
            class:ic-tn__guide--pipe={showPipe}
            style:width="{INDENT_REM[size ?? 'md']}rem"
          ></span>
        {/each}
        <span
          class="ic-tn__guide ic-tn__guide--branch"
          class:ic-tn__guide--last={row.isLast}
          style:width="{INDENT_REM[size ?? 'md']}rem"
        ></span>
      </span>
    {/if}
    <span class="ic-vr__shimmer"></span>
  </div>
{:else}
  <div
    class="ic-tn__row"
    class:ic-tn__row--expanded={isExpanded}
    class:ic-tn__row--disabled={disabled || (!isFolder && selectable && atMaxSelections && !isItemSelected(node.key))}
    style="padding-left: {showLine ? 0 : row.depth * INDENT_REM[size ?? 'md']}rem"
    role="treeitem"
    tabindex={-1}
    aria-expanded={isFolder ? isExpanded : undefined}
    aria-selected={selectable && !isFolder ? isItemSelected(node.key) : undefined}
    onclick={handleRowClick}
    oncontextmenu={handleContextMenu}
  >
    <!-- Tree line guides -->
    {#if showLine}
      <span class="ic-tn__guides">
        {#each row.parentLines as showPipe, pi (pi)}
          <span
            class="ic-tn__guide"
            class:ic-tn__guide--pipe={showPipe}
            style:width="{INDENT_REM[size ?? 'md']}rem"
          ></span>
        {/each}
        <span
          class="ic-tn__guide ic-tn__guide--branch"
          class:ic-tn__guide--last={row.isLast}
          style:width="{INDENT_REM[size ?? 'md']}rem"
        ></span>
      </span>
    {/if}

    <!-- Folder icon / spinner -->
    {#if isFolder}
      {#if isLoading}
        <span class="ic-tn__folder ic-vr__spinner-wrap">
          <span class="ic-vr__spinner" style="width: {FOLDER_SIZES[size] ?? 14}px; height: {FOLDER_SIZES[size] ?? 14}px"></span>
        </span>
      {:else}
        <span
          class="ic-tn__folder"
          role="button"
          tabindex={-1}
          onclick={handleFolderClick}
        >
          {@html isExpanded ? folderOpenSvg : folderSvg}
        </span>
      {/if}
    {/if}

    <!-- Content (icon + label) -->
    <span
      class="ic-tn__content"
      class:ic-tn__content--selected={selectable && !isFolder && isItemSelected(node.key)}
    >
      {#if node.icon}
        {@const svg = resolveIcon(node.icon, ICON_SIZES[size] ?? 12)}
        {#if svg}
          <span class="ic-tn__icon">{@html svg}</span>
        {/if}
      {/if}
      <span class="ic-tn__label">{#if labelSegments}{#each labelSegments as seg, si (si)}{#if seg.highlight}<mark class="ic-tn__highlight">{seg.text}</mark>{:else}{seg.text}{/if}{/each}{:else}{node.name}{/if}</span>
    </span>
  </div>
{/if}

{#if ctxMenu}
  <ContextMenu entries={ctxMenu.entries} x={ctxMenu.x} y={ctxMenu.y}
      onaction={handleCtxAction} onclose={() => { ctxMenu = null; }} />
{/if}

<style>
  .ic-vr--placeholder {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.25rem 0.5rem;
    user-select: none;
  }

  .ic-vr__shimmer {
    height: 0.625rem;
    width: 40%;
    min-width: 3rem;
    max-width: 8rem;
    border-radius: 2px;
    background: linear-gradient(
      90deg,
      var(--ic-muted) 25%,
      var(--ic-secondary) 50%,
      var(--ic-muted) 75%
    );
    background-size: 200% 100%;
    animation: ic-shimmer 1.5s ease-in-out infinite;
  }

  @keyframes ic-shimmer {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }

  .ic-vr__spinner-wrap {
    cursor: default;
  }

  .ic-vr__spinner {
    display: block;
    border: 2px solid var(--ic-border);
    border-top-color: var(--ic-primary);
    border-radius: 50%;
    animation: ic-vr-spin 0.6s linear infinite;
  }

  @keyframes ic-vr-spin {
    to { transform: rotate(360deg); }
  }
</style>
