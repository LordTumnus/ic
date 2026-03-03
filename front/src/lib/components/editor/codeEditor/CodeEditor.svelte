<script lang="ts">
  import { untrack, tick } from 'svelte';
  import { EditorView } from '@codemirror/view';
  import { EditorState, type Extension } from '@codemirror/state';
  import { foldAll, unfoldAll } from '@codemirror/language';
  import { undo as undoCmd, redo as redoCmd } from '@codemirror/commands';
  import type { Resolution } from '$lib/types';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import { resolveIcon } from '$lib/utils/icons';
  import logger from '$lib/core/logger';
  import {
    createCompartments,
    buildExtensions,
    loadLanguage,
    languageExt,
    readOnlyExt,
    lineNumbersExt,
    lineWrappingExt,
    highlightActiveLineExt,
    tabSizeExt,
    placeholderExt2,
    fontSizeExt,
    bracketMatchingExt,
    codeFoldingExt,
    highlightSelectionMatchesExt,
    closeBracketsExt,
    allowMultipleSelectionsExt,
    zebraStripesExt,
    uneditableLinesExt,
    highlightedLinesExt,
    rulersExt,
    indentGuidesExt,
    scrollPastEndExt,
    SearchQuery,
    setSearchQuery,
    findNext as cmFindNext,
    findPrevious as cmFindPrev,
    replaceNext as cmReplaceNext,
    replaceAll as cmReplaceAll,
  } from './extensions';

  // ─── Props ───────────────────────────────────────────
  let {
    // Data props
    value = $bindable(''),
    language = $bindable('matlab'),
    readOnly = $bindable(false),
    height = $bindable<CssSize>('100%'),
    lineNumbers: showLineNumbers = $bindable(true),
    lineWrapping = $bindable(false),
    highlightActiveLine: showHighlightActiveLine = $bindable(true),
    tabSize = $bindable(4),
    placeholder = $bindable(''),
    fontSize = $bindable(0),
    bracketMatching = $bindable(true),
    codeFolding = $bindable(false),
    showSearch = $bindable(false),
    highlightSelectionMatches: showHighlightSelectionMatches = $bindable(false),
    closeBrackets: showCloseBrackets = $bindable(false),
    allowMultipleSelections = $bindable(false),
    zebraStripes: showZebraStripes = $bindable(false),
    zebraStripeStep = $bindable(2),
    uneditableLines: uneditableLineNumbers = $bindable<number | number[]>([]),
    highlightedLines: highlightedLineNumbers = $bindable<number | number[]>([]),
    rulers: rulerColumns = $bindable<number | number[]>([]),
    indentGuides: showIndentGuides = $bindable(false),
    scrollPastEnd: showScrollPastEnd = $bindable(false),
    showStatusBar = $bindable(true),

    // Read-only props (frontend → MATLAB)
    lineCount = $bindable(0),
    cursorLine = $bindable(1),
    cursorColumn = $bindable(1),
    selectionCount = $bindable(1),

    // Events
    valueChanged,
    selectionChanged,
    focusChanged,

    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    blur = $bindable((): Resolution => ({ success: true, data: null })),
    gotoLine = $bindable((_line: number): Resolution => ({ success: true, data: null })),
    setSelection = $bindable(
      (_fl: number, _fc: number, _tl: number, _tc: number): Resolution => ({
        success: true,
        data: null,
      }),
    ),
    getSelection = $bindable((): Resolution => ({ success: true, data: '' })),
    replaceSelection = $bindable(
      (_text: string): Resolution => ({ success: true, data: null }),
    ),
    undo = $bindable((): Resolution => ({ success: true, data: null })),
    redo = $bindable((): Resolution => ({ success: true, data: null })),
    foldAllMethod = $bindable((): Resolution => ({ success: true, data: null })),
    unfoldAllMethod = $bindable((): Resolution => ({ success: true, data: null })),
    scrollToLine = $bindable((_line: number): Resolution => ({ success: true, data: null })),
  }: {
    value?: string;
    language?: string;
    readOnly?: boolean;
    height?: CssSize;
    lineNumbers?: boolean;
    lineWrapping?: boolean;
    highlightActiveLine?: boolean;
    tabSize?: number;
    placeholder?: string;
    fontSize?: number;
    bracketMatching?: boolean;
    codeFolding?: boolean;
    showSearch?: boolean;
    highlightSelectionMatches?: boolean;
    closeBrackets?: boolean;
    allowMultipleSelections?: boolean;
    zebraStripes?: boolean;
    zebraStripeStep?: number;
    uneditableLines?: number | number[];
    highlightedLines?: number | number[];
    rulers?: number | number[];
    indentGuides?: boolean;
    scrollPastEnd?: boolean;
    showStatusBar?: boolean;
    lineCount?: number;
    cursorLine?: number;
    cursorColumn?: number;
    selectionCount?: number;
    valueChanged?: (data?: unknown) => void;
    selectionChanged?: (data?: unknown) => void;
    focusChanged?: (data?: unknown) => void;
    focus?: () => Resolution;
    blur?: () => Resolution;
    gotoLine?: (line: number) => Resolution;
    setSelection?: (fl: number, fc: number, tl: number, tc: number) => Resolution;
    getSelection?: () => Resolution;
    replaceSelection?: (text: string) => Resolution;
    undo?: () => Resolution;
    redo?: () => Resolution;
    foldAllMethod?: () => Resolution;
    unfoldAllMethod?: () => Resolution;
    scrollToLine?: (line: number) => Resolution;
  } = $props();

  // ─── Internal state ──────────────────────────────────

  let containerEl: HTMLDivElement;
  let view: EditorView | null = null;
  const compartments = createCompartments();

  // Guard flag: prevents echo loops during external value sync
  let updatingFromProp = false;

  // Resolved language extension (loaded async)
  let langExt: Extension = $state([]);

  // Search bar icons (resolved once, 14px)
  const icChevronRight = resolveIcon('chevron-right', 14);
  const icChevronDown = resolveIcon('chevron-down', 14);
  const icArrowUp = resolveIcon('arrow-up', 14);
  const icArrowDown = resolveIcon('arrow-down', 14);
  const icX = resolveIcon('x', 14);
  const icCaseSensitive = resolveIcon('case-sensitive', 14);
  const icReplace = resolveIcon('replace', 14);
  const icReplaceAll = resolveIcon('replace-all', 14);

  /** MATLAB encodes `[1]` as a scalar — normalize to array. */
  function asArray(v: number | number[]): number[] {
    return Array.isArray(v) ? v : (v == null ? [] : [v]);
  }

  // ─── Computed ────────────────────────────────────────

  const displayLanguage = $derived(
    language === 'plain' ? 'Text' : language.charAt(0).toUpperCase() + language.slice(1),
  );

  // ─── Language loading ────────────────────────────────

  $effect(() => {
    const lang = language;
    loadLanguage(lang).then((ext) => {
      langExt = ext;
      if (view) {
        view.dispatch({
          effects: compartments.language.reconfigure(languageExt(ext)),
        });
      }
    });
  });

  // ─── Editor mount ────────────────────────────────────
  // Only tracks `containerEl`. All prop reads are untracked because
  // compartment-reconfiguration effects handle live prop updates.

  $effect(() => {
    const el = containerEl;
    if (!el) return;

    return untrack(() => {
      const updateListener = EditorView.updateListener.of((update) => {
        if (update.docChanged && !updatingFromProp) {
          const newVal = update.state.doc.toString();
          value = newVal;
          lineCount = update.state.doc.lines;
          valueChanged?.({ value: newVal });
        }
        if (update.selectionSet) {
          const sel = update.state.selection.main;
          const line = update.state.doc.lineAt(sel.head);
          const newLine = line.number;
          const newCol = sel.head - line.from + 1;
          const newSelCount = update.state.selection.ranges.length;
          cursorLine = newLine;
          cursorColumn = newCol;
          selectionCount = newSelCount;
          selectionChanged?.({ line: newLine, column: newCol });
        }
        if (update.focusChanged) {
          focusChanged?.({ focused: update.view.hasFocus });
        }
      });

      const state = EditorState.create({
        doc: value,
        extensions: [
          ...buildExtensions(compartments, {
            language: langExt,
            readOnly,
            showLineNumbers,
            lineWrapping,
            showHighlightActiveLine,
            tabSize,
            placeholder,
            fontSize,
            showBracketMatching: bracketMatching,
            codeFolding,
            showHighlightSelectionMatches,
            showCloseBrackets,
            allowMultipleSelections,
            showZebraStripes,
            zebraStripeStep,
            uneditableLineNumbers: asArray(uneditableLineNumbers),
            highlightedLineNumbers: asArray(highlightedLineNumbers),
            rulerColumns: asArray(rulerColumns),
            showIndentGuides,
            showScrollPastEnd,
          }),
          updateListener,
        ],
      });

      const editorView = new EditorView({ state, parent: el });
      view = editorView;
      lineCount = editorView.state.doc.lines;
      logger.debug('CodeEditor', 'mounted', { language });

      return () => {
        editorView.destroy();
        view = null;
        logger.debug('CodeEditor', 'destroyed');
      };
    });
  });

  // ─── Value sync (MATLAB → editor) ───────────────────

  $effect(() => {
    const v = value;
    if (!view) return;
    const current = view.state.doc.toString();
    if (v === current) return;

    updatingFromProp = true;
    view.dispatch({
      changes: {
        from: 0,
        to: view.state.doc.length,
        insert: v,
      },
    });
    lineCount = view.state.doc.lines;
    updatingFromProp = false;
  });

  // ─── Compartment reconfiguration effects ─────────────
  // Each prop change dispatches a reconfigure to its compartment.

  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.readOnly.reconfigure(readOnlyExt(readOnly)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.lineNumbers.reconfigure(lineNumbersExt(showLineNumbers)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.lineWrapping.reconfigure(lineWrappingExt(lineWrapping)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.highlightActiveLine.reconfigure(highlightActiveLineExt(showHighlightActiveLine)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.tabSize.reconfigure(tabSizeExt(tabSize)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.placeholder.reconfigure(placeholderExt2(placeholder)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.fontSize.reconfigure(fontSizeExt(fontSize)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.bracketMatching.reconfigure(bracketMatchingExt(bracketMatching)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.codeFolding.reconfigure(codeFoldingExt(codeFolding)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.highlightSelectionMatches.reconfigure(highlightSelectionMatchesExt(showHighlightSelectionMatches)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.closeBrackets.reconfigure(closeBracketsExt(showCloseBrackets)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.allowMultipleSelections.reconfigure(allowMultipleSelectionsExt(allowMultipleSelections)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.zebraStripes.reconfigure(zebraStripesExt(showZebraStripes, zebraStripeStep)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.uneditableLines.reconfigure(uneditableLinesExt(asArray(uneditableLineNumbers))) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.highlightedLines.reconfigure(highlightedLinesExt(asArray(highlightedLineNumbers))) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.rulers.reconfigure(rulersExt(asArray(rulerColumns))) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.indentGuides.reconfigure(indentGuidesExt(showIndentGuides, tabSize)) });
  });
  $effect(() => {
    if (!view) return;
    view.dispatch({ effects: compartments.scrollPastEnd.reconfigure(scrollPastEndExt(showScrollPastEnd)) });
  });

  // ─── Custom search panel ─────────────────────────────

  let searchText = $state('');
  let replaceText = $state('');
  let replaceOpen = $state(false);
  let matchCase = $state(false);
  let searchInputEl = $state<HTMLInputElement | null>(null);

  // Sync search query to CM (highlights matches in the editor)
  $effect(() => {
    if (!view) return;
    if (showSearch && searchText) {
      view.dispatch({
        effects: setSearchQuery.of(new SearchQuery({
          search: searchText,
          replace: replaceText,
          caseSensitive: matchCase,
        })),
      });
    } else {
      view.dispatch({
        effects: setSearchQuery.of(new SearchQuery({ search: '' })),
      });
    }
  });

  // Focus the search input when the panel opens
  $effect(() => {
    if (showSearch) {
      tick().then(() => {
        searchInputEl?.focus();
        searchInputEl?.select();
      });
    }
  });

  function openSearchBar(withReplace = false) {
    if (view) {
      const sel = view.state.selection.main;
      if (!sel.empty) {
        searchText = view.state.sliceDoc(sel.from, sel.to);
      }
    }
    showSearch = true;
    if (withReplace) replaceOpen = true;
  }

  function closeSearchBar() {
    showSearch = false;
    replaceOpen = false;
    view?.focus();
  }

  function doFindNext() { if (view && searchText) cmFindNext(view); }
  function doFindPrev() { if (view && searchText) cmFindPrev(view); }
  function doReplace() { if (view && searchText) cmReplaceNext(view); }
  function doReplaceAll() { if (view && searchText) cmReplaceAll(view); }

  function handleGlobalKeyDown(e: KeyboardEvent) {
    const mod = e.metaKey || e.ctrlKey;
    if (mod && e.key === 'f') {
      e.preventDefault();
      openSearchBar(false);
    } else if (mod && e.key === 'h') {
      e.preventDefault();
      openSearchBar(true);
    } else if (e.key === 'Escape' && showSearch) {
      closeSearchBar();
    }
  }

  function handleSearchKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (e.shiftKey) doFindPrev();
      else doFindNext();
    }
  }

  function handleReplaceKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      e.preventDefault();
      doReplace();
    }
  }

  // ─── Method implementations ──────────────────────────

  $effect(() => {
    focus = (): Resolution => {
      view?.focus();
      return { success: true, data: null };
    };

    blur = (): Resolution => {
      view?.contentDOM.blur();
      return { success: true, data: null };
    };

    gotoLine = (line: number): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      const total = view.state.doc.lines;
      const clamped = Math.max(1, Math.min(line, total));
      const pos = view.state.doc.line(clamped).from;
      view.dispatch({
        selection: { anchor: pos },
        scrollIntoView: true,
      });
      return { success: true, data: null };
    };

    setSelection = (fl: number, fc: number, tl: number, tc: number): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      const doc = view.state.doc;
      const fromLine = doc.line(Math.max(1, Math.min(fl, doc.lines)));
      const toLine = doc.line(Math.max(1, Math.min(tl, doc.lines)));
      const anchor = fromLine.from + Math.max(0, fc - 1);
      const head = toLine.from + Math.max(0, tc - 1);
      view.dispatch({
        selection: { anchor, head },
        scrollIntoView: true,
      });
      return { success: true, data: null };
    };

    getSelection = (): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      const { from, to } = view.state.selection.main;
      const text = view.state.sliceDoc(from, to);
      return { success: true, data: text };
    };

    replaceSelection = (text: string): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      view.dispatch(view.state.replaceSelection(text));
      return { success: true, data: null };
    };

    undo = (): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      undoCmd(view);
      return { success: true, data: null };
    };

    redo = (): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      redoCmd(view);
      return { success: true, data: null };
    };

    foldAllMethod = (): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      foldAll(view);
      return { success: true, data: null };
    };

    unfoldAllMethod = (): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      unfoldAll(view);
      return { success: true, data: null };
    };

    scrollToLine = (line: number): Resolution => {
      if (!view) return { success: false, data: 'Editor not mounted' };
      const total = view.state.doc.lines;
      const clamped = Math.max(1, Math.min(line, total));
      const pos = view.state.doc.line(clamped).from;
      view.dispatch({
        effects: EditorView.scrollIntoView(pos, { y: 'center' }),
      });
      return { success: true, data: null };
    };
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="ic-ce" style:height={toSize(height)} onkeydown={handleGlobalKeyDown}>
  {#if showSearch}
    <div class="ic-ce__search" role="search">
      <div class="ic-ce__search-row">
        <button
          class="ic-ce__search-btn ic-ce__search-toggle"
          onclick={() => { replaceOpen = !replaceOpen }}
          title={replaceOpen ? 'Hide Replace' : 'Show Replace'}
        >{@html replaceOpen ? icChevronDown : icChevronRight}</button>
        <input
          class="ic-ce__search-field"
          type="text"
          placeholder="Find"
          bind:this={searchInputEl}
          bind:value={searchText}
          onkeydown={handleSearchKeyDown}
        />
        <button class="ic-ce__search-btn" class:ic-ce__search-btn--active={matchCase} onclick={() => { matchCase = !matchCase }} title="Match Case">{@html icCaseSensitive}</button>
        <button class="ic-ce__search-btn" onclick={doFindPrev} title="Previous Match (Shift+Enter)">{@html icArrowUp}</button>
        <button class="ic-ce__search-btn" onclick={doFindNext} title="Next Match (Enter)">{@html icArrowDown}</button>
        <button class="ic-ce__search-btn" onclick={closeSearchBar} title="Close (Escape)">{@html icX}</button>
      </div>
      {#if replaceOpen}
        <div class="ic-ce__search-row">
          <div class="ic-ce__search-toggle-spacer"></div>
          <input
            class="ic-ce__search-field"
            type="text"
            placeholder="Replace"
            bind:value={replaceText}
            onkeydown={handleReplaceKeyDown}
          />
          <button class="ic-ce__search-btn" onclick={doReplace} title="Replace">{@html icReplace}</button>
          <button class="ic-ce__search-btn" onclick={doReplaceAll} title="Replace All">{@html icReplaceAll}</button>
        </div>
      {/if}
    </div>
  {/if}

  <div class="ic-ce__editor" bind:this={containerEl}></div>

  {#if showStatusBar}
    <div class="ic-ce__status">
      <span class="ic-ce__status-item">
        Ln {cursorLine}, Col {cursorColumn}
      </span>
      {#if selectionCount > 1}
        <span class="ic-ce__status-item">
          {selectionCount} selections
        </span>
      {/if}
      <span class="ic-ce__status-spacer"></span>
      <span class="ic-ce__status-item">
        {displayLanguage}
      </span>
    </div>
  {/if}
</div>

<style>
  .ic-ce {
    /* ── Editor color tokens ── */
    --ic-ce-active-line: rgba(66, 133, 244, 0.06);
    --ic-ce-active-gutter: rgba(66, 133, 244, 0.08);
    --ic-ce-selection: rgba(66, 133, 244, 0.20);
    --ic-ce-selection-focus: rgba(66, 133, 244, 0.25);
    --ic-ce-selection-match: rgba(255, 193, 7, 0.20);
    --ic-ce-bracket: rgba(66, 133, 244, 0.08);
    --ic-ce-bracket-bad: rgba(239, 83, 80, 0.15);
    --ic-ce-search: rgba(255, 193, 7, 0.25);
    --ic-ce-search-active: rgba(66, 133, 244, 0.25);
    --ic-ce-stripe: rgba(120, 100, 70, 0.04);
    --ic-ce-locked: rgba(239, 83, 80, 0.06);
    --ic-ce-highlight: rgba(255, 193, 7, 0.12);
    --ic-ce-ruler: rgba(128, 128, 128, 0.15);
    --ic-ce-indent-guide: rgba(140, 120, 190, 0.22);
    --ic-ce-fold: var(--ic-muted-foreground);

    position: relative;
    display: flex;
    flex-direction: column;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: clip;
    background-color: var(--ic-background);
    font-family: 'Roboto Mono', ui-monospace, monospace;
  }

  .ic-ce__editor {
    flex: 1;
    min-height: 0;
    overflow: clip;
  }

  /* Ensure CodeMirror fills the container */
  .ic-ce__editor :global(.cm-editor) {
    height: 100%;
  }

  /* ── Custom search bar — floating top-right (VS Code style) ── */
  .ic-ce__search {
    position: absolute;
    top: 0;
    right: 16px;
    z-index: 10;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-top: none;
    border-radius: 0 0 4px 4px;
    padding: 4px 6px;
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.12);
    font-size: 0.8em;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }

  .ic-ce__search-row {
    display: flex;
    align-items: center;
    gap: 2px;
  }

  .ic-ce__search-field {
    font-family: inherit;
    font-size: inherit;
    border: 1px solid var(--ic-border);
    background-color: var(--ic-background);
    color: var(--ic-foreground);
    padding: 2px 6px;
    border-radius: 2px;
    outline: none;
    min-width: 14em;
    line-height: 1.4;
  }

  .ic-ce__search-field:focus {
    border-color: var(--ic-primary);
  }

  .ic-ce__search-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    color: var(--ic-muted-foreground);
    padding: 2px;
    cursor: pointer;
    border-radius: 2px;
    flex-shrink: 0;
    width: 22px;
    height: 22px;
  }

  .ic-ce__search-btn:hover {
    background-color: var(--ic-muted);
    color: var(--ic-foreground);
  }

  .ic-ce__search-btn--active {
    color: var(--ic-primary);
  }

  .ic-ce__search-toggle {
    width: 18px;
  }

  .ic-ce__search-toggle-spacer {
    width: 18px;
    flex-shrink: 0;
  }

  .ic-ce__status {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 2px 8px;
    border-top: 1px solid var(--ic-border);
    background-color: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    font-size: 0.75em;
    line-height: 1.6;
    user-select: none;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
  }

  .ic-ce__status-item {
    white-space: nowrap;
  }

  .ic-ce__status-spacer {
    flex: 1;
  }
</style>
