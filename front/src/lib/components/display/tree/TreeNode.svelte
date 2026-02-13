<script lang="ts">
  import TreeNode from './TreeNode.svelte';
  import { resolveIconType, type IconTypeData } from '$lib/utils/icons';
  import { type TreeNode as TreeNodeData } from '$lib/utils/tree-utils';

  const ICON_SIZES: Record<string, number> = { sm: 10, md: 12, lg: 14 };
  const INDENT_REM: Record<string, number> = { sm: 1, md: 1.25, lg: 1.5 };
  const FOLDER_SIZES: Record<string, number> = { sm: 12, md: 14, lg: 16 };

  function resolveIcon(icon: string | IconTypeData | undefined, sz: string): string {
    return resolveIconType(icon, ICON_SIZES[sz] ?? 12);
  }

  // --- Props ---
  let {
    node,
    depth = 0,
    size = 'md',
    selectable = true,
    disabled = false,
    showLine = false,
    lazyLoad = true,
    isLast = false,
    parentLines = [] as boolean[],
    expandedKeys,
    isItemSelected,
    atMaxSelections = false,
    ontoggle,
    onexpandchange,
  }: {
    node: TreeNodeData;
    depth?: number;
    size?: string;
    selectable?: boolean;
    disabled?: boolean;
    showLine?: boolean;
    lazyLoad?: boolean;
    isLast?: boolean;
    parentLines?: boolean[];
    expandedKeys: Set<string>;
    isItemSelected: (key: string) => boolean;
    atMaxSelections?: boolean;
    ontoggle: (key: string) => void;
    onexpandchange: (key: string, expanded: boolean) => void;
  } = $props();

  const isFolder = $derived((node.children?.length ?? 0) > 0);
  const isExpanded = $derived(expandedKeys.has(node.key));

  // Folder icons (replaces chevrons)
  const folderSvg = $derived(resolveIconType('folder', FOLDER_SIZES[size] ?? 14));
  const folderOpenSvg = $derived(resolveIconType('folder-open', FOLDER_SIZES[size] ?? 14));

  // --- Handlers ---
  function handleFolderClick(e: MouseEvent) {
    e.stopPropagation();
    onexpandchange(node.key, !isExpanded);
  }

  function handleRowClick() {
    if (disabled) return;
    if (isFolder) {
      onexpandchange(node.key, !isExpanded);
    } else if (selectable) {
      if (atMaxSelections && !isItemSelected(node.key)) return;
      ontoggle(node.key);
    }
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<!-- svelte-ignore a11y_click_events_have_key_events -->
<div class="ic-tn">
  <div
    class="ic-tn__row"
    class:ic-tn__row--expanded={isExpanded}
    class:ic-tn__row--disabled={disabled || (!isFolder && selectable && atMaxSelections && !isItemSelected(node.key))}
    style="padding-left: {showLine ? 0 : depth * INDENT_REM[size ?? 'md']}rem"
    role="treeitem"
    tabindex={-1}
    aria-expanded={isFolder ? isExpanded : undefined}
    aria-selected={selectable && !isFolder ? isItemSelected(node.key) : undefined}
    onclick={handleRowClick}
  >
    <!-- Tree line guides (when showLine is on) -->
    {#if showLine}
      <span class="ic-tn__guides">
        {#each parentLines as showPipe, pi (pi)}
          <span
            class="ic-tn__guide"
            class:ic-tn__guide--pipe={showPipe}
            style:width="{INDENT_REM[size ?? 'md']}rem"
          ></span>
        {/each}
        <span
          class="ic-tn__guide ic-tn__guide--branch"
          class:ic-tn__guide--last={isLast}
          style:width="{INDENT_REM[size ?? 'md']}rem"
        ></span>
      </span>
    {/if}

    <!-- Folder icon (folders only — leaves have no spacer) -->
    {#if isFolder}
      <span
        class="ic-tn__folder"
        role="button"
        tabindex={-1}
        onclick={handleFolderClick}
      >
        {@html isExpanded ? folderOpenSvg : folderSvg}
      </span>
    {/if}

    <!-- Content (icon + label) — highlighted when selected -->
    <span
      class="ic-tn__content"
      class:ic-tn__content--selected={selectable && !isFolder && isItemSelected(node.key)}
    >
      {#if node.icon}
        {@const svg = resolveIcon(node.icon, size)}
        {#if svg}
          <span class="ic-tn__icon">{@html svg}</span>
        {/if}
      {/if}
      <span class="ic-tn__label">{node.name}</span>
    </span>
  </div>

  <!-- Children (lazy: mount only when expanded; eager: always in DOM, hidden when collapsed) -->
  {#if isFolder && (!lazyLoad || isExpanded)}
    <div class="ic-tn__children" style:display={isExpanded ? null : 'none'}>
      {#each node.children as child, ci (child.key)}
        <TreeNode
          node={child}
          depth={depth + 1}
          {size}
          {selectable}
          {disabled}
          {showLine}
          {lazyLoad}
          isLast={ci === node.children.length - 1}
          parentLines={showLine ? [...parentLines, !isLast] : []}
          {expandedKeys}
          {isItemSelected}
          {atMaxSelections}
          {ontoggle}
          {onexpandchange}
        />
      {/each}
    </div>
  {/if}
</div>

<style>
  /* ===== ROW ===== */
  .ic-tn__row {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.25rem 0.5rem;
    cursor: pointer;
    color: var(--ic-foreground);
    user-select: none;
    transition: background-color 0.1s ease;
  }

  .ic-tn__row:hover,
  .ic-tn__row--expanded {
    background: var(--ic-secondary);
  }

  .ic-tn__row--disabled {
    opacity: 0.4;
    cursor: not-allowed;
    pointer-events: none;
  }

  /* ===== FOLDER ICON (replaces chevron) ===== */
  .ic-tn__folder {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 16px;
    height: 16px;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    transition: color 0.1s ease;
  }

  .ic-tn__folder :global(svg) {
    fill: currentColor;
    fill-opacity: 0.15;
  }

  .ic-tn__folder:hover {
    color: var(--ic-foreground);
  }

  /* ===== TREE LINE GUIDES ===== */
  .ic-tn__guides {
    display: flex;
    align-self: stretch;
    flex-shrink: 0;
    margin: -0.25rem 0; /* bleed into row padding so lines connect */
  }

  .ic-tn__guide {
    position: relative;
    flex-shrink: 0;
    align-self: stretch;
  }

  /* Pass-through vertical line (│) */
  .ic-tn__guide--pipe::before {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }

  /* Connector branch — vertical part (├ default, └ when last) */
  .ic-tn__guide--branch::before {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }

  /* Last child: vertical stops at center (└) */
  .ic-tn__guide--branch.ic-tn__guide--last::before {
    bottom: 50%;
  }

  /* Connector branch — horizontal part (extends through flex gap to icon) */
  .ic-tn__guide--branch::after {
    content: '';
    position: absolute;
    left: 50%;
    top: 50%;
    right: -0.125rem;
    height: 1px;
    background: var(--ic-border);
  }

  /* ===== CONTENT (icon + label — selection highlight) ===== */
  .ic-tn__content {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    max-width: 100%;
    min-width: 0;
    border-radius: 2px;
    padding: 1px 0.25rem;
    margin: -1px -0.25rem;
    transition: background-color 0.12s ease, color 0.12s ease;
  }

  .ic-tn__content--selected {
    position: relative;
    color: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  .ic-tn__content--selected::before {
    content: '';
    position: absolute;
    inset: 0;
    background: var(--ic-primary);
    opacity: 0.13;
    border-radius: inherit;
    pointer-events: none;
  }

  /* ===== ICON ===== */
  .ic-tn__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }

  .ic-tn__content--selected .ic-tn__icon {
    color: var(--ic-primary);
  }

  /* ===== LABEL ===== */
  .ic-tn__label {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
