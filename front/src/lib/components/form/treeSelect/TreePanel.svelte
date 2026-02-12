<script lang="ts">
  import TreePanel from './TreePanel.svelte';

  import { resolveIconType, type IconTypeData } from '$lib/utils/icons';

  interface TreeNodeData {
    key: string;
    name: string;
    icon?: string | IconTypeData;
    children: TreeNodeData[];
  }

  const ICON_SIZES: Record<string, number> = { sm: 10, md: 12, lg: 14 };

  function resolveIcon(icon: string | IconTypeData | undefined, sz: string): string {
    return resolveIconType(icon, ICON_SIZES[sz] ?? 12);
  }

  // --- Module-level helper ---
  function getAllLeaves(node: TreeNodeData): string[] {
    if (!node.children?.length) return [node.key];
    return node.children.flatMap((c) => getAllLeaves(c));
  }

  // --- Props ---
  let {
    nodes,
    size = 'md',
    maxHeight = 200,
    maxPanelWidth = 240,
    openOnHover = true,
    isItemSelected,
    atMaxSelections = false,
    ontoggle,
    ontogglefolder,
  }: {
    nodes: TreeNodeData[];
    size?: string;
    maxHeight?: number;
    maxPanelWidth?: number;
    openOnHover?: boolean;
    isItemSelected: (key: string) => boolean;
    atMaxSelections?: boolean;
    ontoggle: (key: string) => void;
    ontogglefolder: (leafKeys: string[]) => void;
  } = $props();

  // --- Refs & State ---
  let panelRef: HTMLDivElement;
  let rowEls: HTMLDivElement[] = [];
  let expandedIndex = $state(-1);
  let subTop = $state(0);
  let timer: ReturnType<typeof setTimeout> | null = null;

  // --- Check state for any node ---
  function getCheckState(node: TreeNodeData): 'checked' | 'indeterminate' | 'unchecked' {
    if (!node.children?.length) {
      return isItemSelected(node.key) ? 'checked' : 'unchecked';
    }
    const leaves = getAllLeaves(node);
    const count = leaves.filter((k) => isItemSelected(k)).length;
    if (count === 0) return 'unchecked';
    if (count === leaves.length) return 'checked';
    return 'indeterminate';
  }

  // --- Row click ---
  function handleRowClick(node: TreeNodeData) {
    const state = getCheckState(node);
    if (node.children?.length > 0) {
      // Folder: can only toggle if fully checked (deselect) or not at max (select)
      if (atMaxSelections && state !== 'checked') return;
      ontogglefolder(getAllLeaves(node));
    } else {
      if (atMaxSelections && state === 'unchecked') return;
      ontoggle(node.key);
    }
  }

  // --- Hover / expand ---
  function clearTimer() {
    if (timer != null) { clearTimeout(timer); timer = null; }
  }

  function positionSub(index: number) {
    requestAnimationFrame(() => {
      const rr = rowEls[index]?.getBoundingClientRect();
      const pr = panelRef?.getBoundingClientRect();
      if (rr && pr) subTop = rr.top - pr.top;
    });
  }

  function handleRowEnter(index: number) {
    clearTimer();
    if (!openOnHover) return;
    const node = nodes[index];
    if (node?.children?.length > 0 && index !== expandedIndex) {
      timer = setTimeout(() => {
        expandedIndex = index;
        positionSub(index);
      }, 150);
    }
  }

  function handleChevronClick(index: number, e: MouseEvent) {
    e.stopPropagation();
    clearTimer();
    if (expandedIndex === index) {
      expandedIndex = -1;
    } else {
      expandedIndex = index;
      positionSub(index);
    }
  }

  function handleSubEnter() {
    clearTimer();
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="ic-tp">
  <div
    bind:this={panelRef}
    class="ic-tp__panel"
    class:ic-tp__panel--sm={size === 'sm'}
    class:ic-tp__panel--md={size === 'md'}
    class:ic-tp__panel--lg={size === 'lg'}
    style:max-width="{maxPanelWidth}px"
  >
    <div class="ic-tp__list" style:max-height="{maxHeight}px">
      {#each nodes as node, i (node.key)}
        {@const state = getCheckState(node)}
        {@const isFolder = (node.children?.length ?? 0) > 0}
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <div
          bind:this={rowEls[i]}
          class="ic-tp__row"
          class:ic-tp__row--expanded={i === expandedIndex}
          class:ic-tp__row--disabled={!isFolder && atMaxSelections && state === 'unchecked'}
          role="option"
          tabindex={-1}
          aria-selected={state === 'checked'}
          onpointerenter={() => handleRowEnter(i)}
          onclick={() => handleRowClick(node)}
        >
          <!-- Checkbox (supports checked / indeterminate / unchecked) -->
          <span
            class="ic-tp__check"
            class:ic-tp__check--on={state === 'checked'}
            class:ic-tp__check--mixed={state === 'indeterminate'}
          >
            {#if state === 'checked'}
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                <path d="M2 5L4 7L8 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            {:else if state === 'indeterminate'}
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                <line x1="2.5" y1="5" x2="7.5" y2="5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
              </svg>
            {/if}
          </span>

          <!-- Icon (optional) -->
          {#if node.icon}
            {@const svg = resolveIcon(node.icon, size)}
            {#if svg}
              <span class="ic-tp__icon">{@html svg}</span>
            {/if}
          {/if}

          <!-- Label -->
          <span class="ic-tp__label">{node.name}</span>

          <!-- Expand zone: separator + chevron (if has children) -->
          {#if isFolder}
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <span
              class="ic-tp__expand"
              role="button"
              tabindex={-1}
              onclick={(e) => handleChevronClick(i, e)}
            >
              <span class="ic-tp__sep"></span>
              <span
                class="ic-tp__chevron"
                class:ic-tp__chevron--open={i === expandedIndex}
              >
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                  <path d="M4 2.5L7 5L4 7.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </span>
            </span>
          {/if}
        </div>
      {/each}
    </div>
  </div>

  <!-- Sub-panel (flex sibling, offset by margin-top for row alignment) -->
  {#if expandedIndex >= 0 && nodes[expandedIndex]?.children?.length > 0}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="ic-tp__sub" style="margin-top: {subTop}px" onpointerenter={handleSubEnter}>
      <TreePanel
        nodes={nodes[expandedIndex].children}
        {size}
        {maxHeight}
        {maxPanelWidth}
        {openOnHover}
        {isItemSelected}
        {atMaxSelections}
        {ontoggle}
        {ontogglefolder}
      />
    </div>
  {/if}
</div>

<style>
  /* ===== FLEX ROW CONTAINER (panel + sub-panel side by side) ===== */
  .ic-tp {
    display: flex;
    flex-direction: row;
    align-items: flex-start;
    flex-shrink: 0;
  }

  /* ===== PANEL BOX ===== */
  .ic-tp__panel {
    min-width: 160px;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    flex-shrink: 0;
  }

  .ic-tp__panel--sm { font-size: 0.75rem; }
  .ic-tp__panel--md { font-size: 0.8125rem; }
  .ic-tp__panel--lg { font-size: 0.9375rem; }

  .ic-tp__list {
    overflow-y: auto;
  }

  /* ===== ROW ===== */
  .ic-tp__row {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.35rem 0.5rem;
    cursor: pointer;
    color: var(--ic-foreground);
    user-select: none;
    transition: background-color 0.1s ease;
  }

  .ic-tp__row:first-child { padding-top: calc(0.35rem + 2px); }
  .ic-tp__row:last-child { padding-bottom: calc(0.35rem + 2px); }

  .ic-tp__row:hover,
  .ic-tp__row--expanded {
    background: var(--ic-secondary);
  }

  .ic-tp__row--disabled {
    opacity: 0.4;
    cursor: not-allowed;
    pointer-events: none;
  }

  /* ===== CHECKBOX (checked / indeterminate / unchecked) ===== */
  .ic-tp__check {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
    flex-shrink: 0;
    transition: background-color 0.12s ease, border-color 0.12s ease;
  }

  .ic-tp__check--on,
  .ic-tp__check--mixed {
    background: var(--ic-primary);
    border-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
  }

  /* ===== ICON ===== */
  .ic-tp__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }

  /* ===== LABEL ===== */
  .ic-tp__label {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* ===== EXPAND ZONE (separator + chevron, clickable as one) ===== */
  .ic-tp__expand {
    display: flex;
    align-items: center;
    align-self: stretch;
    flex-shrink: 0;
    cursor: pointer;
    margin: -0.35rem -0.5rem -0.35rem 0;
    padding: 0.35rem 0.5rem 0.35rem 0;
  }

  .ic-tp__expand:hover .ic-tp__chevron {
    opacity: 1;
  }

  /* ===== SEPARATOR (vertical bar) ===== */
  .ic-tp__sep {
    width: 1px;
    align-self: stretch;
    background: var(--ic-border);
    flex-shrink: 0;
  }

  /* ===== CHEVRON ===== */
  .ic-tp__chevron {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    padding: 2px;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    transition: opacity 0.1s ease;
  }

  .ic-tp__chevron--open {
    opacity: 1;
  }

  .ic-tp__chevron--open svg {
    transform: rotate(90deg);
  }

  /* ===== SUB-PANEL (flex sibling, overlaps parent border) ===== */
  .ic-tp__sub {
    flex-shrink: 0;
    margin-left: -1px;
  }
</style>
