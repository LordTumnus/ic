<script lang="ts">
  import MarkdownIt from 'markdown-it';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import { renderMermaid } from '$lib/utils/mermaid-renderer';
  import type { RequestFn } from '$lib/types';
  import { resolveAssetAsDataUri, type AssetData } from '$lib/utils/asset-cache';

  // ─── Props ────────────────────────────────────────────────────────────
  let {
    value = $bindable(''),
    height = $bindable<CssSize>('100%'),
    lineWrapping = $bindable(true),
    sanitize = $bindable(true),
    // Extension toggles
    codeHighlight = $bindable(true),
    math = $bindable(false),
    taskLists = $bindable(true),
    footnotes = $bindable(true),
    subSuperscript = $bindable(true),
    emoji = $bindable(true),
    containers = $bindable(true),
    mark = $bindable(true),
    definitionLists = $bindable(true),
    abbreviations = $bindable(true),
    insert = $bindable(true),
    headingAnchors = $bindable(true),
    attributes = $bindable(false),
    tableOfContents = $bindable(false),
    mermaid = $bindable(false),
    // Request function (for MATLAB-side image fetching)
    request,
  }: {
    value?: string;
    height?: CssSize;
    lineWrapping?: boolean;
    sanitize?: boolean;
    codeHighlight?: boolean;
    math?: boolean;
    taskLists?: boolean;
    footnotes?: boolean;
    subSuperscript?: boolean;
    emoji?: boolean;
    containers?: boolean;
    mark?: boolean;
    definitionLists?: boolean;
    abbreviations?: boolean;
    insert?: boolean;
    headingAnchors?: boolean;
    attributes?: boolean;
    tableOfContents?: boolean;
    mermaid?: boolean;
    request?: RequestFn;
  } = $props();

  // ─── State ────────────────────────────────────────────────────────────
  let md: MarkdownIt = $state(new MarkdownIt({ html: false, linkify: true, typographer: true }));
  const rendered = $derived(md.render(value || ''));

  let katexCssInjected = false;

  // ─── Lazy-loading plugin architecture ─────────────────────────────────
  let buildId = 0;

  $effect(() => {
    const opts = {
      sanitize,
      codeHighlight,
      math,
      taskLists,
      footnotes,
      subSuperscript,
      emoji,
      containers,
      mark,
      definitionLists,
      abbreviations,
      insert,
      headingAnchors,
      attributes,
      tableOfContents,
      mermaid,
    };

    const currentBuild = ++buildId;

    buildInstance(opts)
      .then((instance) => {
        if (currentBuild === buildId) {
          md = instance;
        }
      })
      .catch((err) => {
        console.error('[ic.Markdown] Failed to build instance:', err);
      });
  });

  // Helper: extract plugin function from a dynamically imported module.
  // Handles both ESM default exports and CJS modules where the function
  // might be on .default or be the module itself.
  function getPlugin(mod: Record<string, unknown>): MarkdownIt.PluginSimple {
    if (typeof mod.default === 'function') return mod.default as MarkdownIt.PluginSimple;
    if (typeof mod === 'function') return mod as unknown as MarkdownIt.PluginSimple;
    // Some packages nest the plugin under a named export
    for (const key of Object.keys(mod)) {
      if (typeof mod[key] === 'function') return mod[key] as MarkdownIt.PluginSimple;
    }
    throw new Error(`Could not find plugin function in module: ${Object.keys(mod)}`);
  }

  interface ExtensionOpts {
    sanitize: boolean;
    codeHighlight: boolean;
    math: boolean;
    taskLists: boolean;
    footnotes: boolean;
    subSuperscript: boolean;
    emoji: boolean;
    containers: boolean;
    mark: boolean;
    definitionLists: boolean;
    abbreviations: boolean;
    insert: boolean;
    headingAnchors: boolean;
    attributes: boolean;
    tableOfContents: boolean;
    mermaid: boolean;
  }

  async function buildInstance(opts: ExtensionOpts): Promise<MarkdownIt> {
    const instance = new MarkdownIt({
      html: !opts.sanitize,
      linkify: true,
      typographer: true,
    });

    // Load all enabled plugins in parallel, then apply sequentially
    const loaders: Promise<(md: MarkdownIt) => void>[] = [];

    // ── Code highlighting (highlight.js) ──────────────────────────────
    if (opts.codeHighlight) {
      loaders.push(
        (async () => {
          const [
            { default: hljs },
            { default: matlab },
            { default: javascript },
            { default: typescript },
            { default: python },
            { default: css },
            { default: xml },
            { default: json },
            { default: bash },
            { default: sql },
            { default: yaml },
            { default: markdownLang },
            { default: c },
            { default: cpp },
          ] = await Promise.all([
            import('highlight.js/lib/core'),
            import('highlight.js/lib/languages/matlab'),
            import('highlight.js/lib/languages/javascript'),
            import('highlight.js/lib/languages/typescript'),
            import('highlight.js/lib/languages/python'),
            import('highlight.js/lib/languages/css'),
            import('highlight.js/lib/languages/xml'),
            import('highlight.js/lib/languages/json'),
            import('highlight.js/lib/languages/bash'),
            import('highlight.js/lib/languages/sql'),
            import('highlight.js/lib/languages/yaml'),
            import('highlight.js/lib/languages/markdown'),
            import('highlight.js/lib/languages/c'),
            import('highlight.js/lib/languages/cpp'),
          ]);

          hljs.registerLanguage('matlab', matlab);
          hljs.registerLanguage('javascript', javascript);
          hljs.registerLanguage('js', javascript);
          hljs.registerLanguage('typescript', typescript);
          hljs.registerLanguage('ts', typescript);
          hljs.registerLanguage('python', python);
          hljs.registerLanguage('py', python);
          hljs.registerLanguage('css', css);
          hljs.registerLanguage('xml', xml);
          hljs.registerLanguage('html', xml);
          hljs.registerLanguage('json', json);
          hljs.registerLanguage('bash', bash);
          hljs.registerLanguage('shell', bash);
          hljs.registerLanguage('sql', sql);
          hljs.registerLanguage('yaml', yaml);
          hljs.registerLanguage('yml', yaml);
          hljs.registerLanguage('markdown', markdownLang);
          hljs.registerLanguage('md', markdownLang);
          hljs.registerLanguage('c', c);
          hljs.registerLanguage('cpp', cpp);

          return (md: MarkdownIt) => {
            md.options.highlight = (code: string, lang: string): string => {
              if (lang && hljs.getLanguage(lang)) {
                try {
                  return hljs.highlight(code, { language: lang }).value;
                } catch { /* fall through */ }
              }
              try {
                return hljs.highlightAuto(code).value;
              } catch { /* fall through */ }
              return '';
            };
          };
        })()
      );
    }

    // ── KaTeX math ────────────────────────────────────────────────────
    if (opts.math) {
      loaders.push(
        (async () => {
          const katexMod = await import('@mdit/plugin-katex');
          const katexPlugin = katexMod.katex ?? katexMod.default ?? katexMod;

          if (!katexCssInjected) {
            try {
              await import('katex/dist/katex.min.css');
              katexCssInjected = true;
            } catch { /* CSS import may fail; math still renders */ }
          }

          return (md: MarkdownIt) => {
            md.use(katexPlugin as MarkdownIt.PluginSimple);
          };
        })()
      );
    }

    // ── Task lists ────────────────────────────────────────────────────
    if (opts.taskLists) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-task-lists');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin, { enabled: false, label: true });
          };
        })()
      );
    }

    // ── Footnotes ─────────────────────────────────────────────────────
    if (opts.footnotes) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-footnote');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin);
          };
        })()
      );
    }

    // ── Subscript / Superscript ───────────────────────────────────────
    if (opts.subSuperscript) {
      loaders.push(
        (async () => {
          const [subMod, supMod] = await Promise.all([
            import('markdown-it-sub'),
            import('markdown-it-sup'),
          ]);
          const subPlugin = getPlugin(subMod as unknown as Record<string, unknown>);
          const supPlugin = getPlugin(supMod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(subPlugin);
            md.use(supPlugin);
          };
        })()
      );
    }

    // ── Emoji ─────────────────────────────────────────────────────────
    if (opts.emoji) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-emoji');
          // v3 exports { full, light, bare } — use `full` for complete shortcode + emoticon support
          const plugin = (mod as Record<string, unknown>).full ?? mod.default ?? mod;
          return (md: MarkdownIt) => {
            md.use(plugin as MarkdownIt.PluginSimple);
          };
        })()
      );
    }

    // ── Custom containers (admonitions) ───────────────────────────────
    if (opts.containers) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-container');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            for (const name of ['warning', 'info', 'tip', 'danger']) {
              md.use(plugin as MarkdownIt.PluginWithParams, name, {
                render(tokens: { nesting: number; info: string }[], idx: number) {
                  if (tokens[idx].nesting === 1) {
                    const title = tokens[idx].info.trim().slice(name.length).trim() || name.toUpperCase();
                    return `<div class="ic-md-container ic-md-container--${name}"><p class="ic-md-container__title">${instance.utils.escapeHtml(title)}</p>\n`;
                  }
                  return '</div>\n';
                },
              });
            }
          };
        })()
      );
    }

    // ── Mark / highlight ──────────────────────────────────────────────
    if (opts.mark) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-mark');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin);
          };
        })()
      );
    }

    // ── Definition lists ────────────────────────────────────────────────
    if (opts.definitionLists) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-deflist');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin);
          };
        })()
      );
    }

    // ── Abbreviations ──────────────────────────────────────────────────
    if (opts.abbreviations) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-abbr');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin);
          };
        })()
      );
    }

    // ── Insert (underline) ─────────────────────────────────────────────
    if (opts.insert) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-ins');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin);
          };
        })()
      );
    }

    // ── Heading anchors ────────────────────────────────────────────────
    if (opts.headingAnchors) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-anchor');
          const plugin = mod.default ?? mod;
          return (md: MarkdownIt) => {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (md as any).use(plugin, {
              permalink: false,
              slugify: (s: string) => s.toLowerCase().replace(/[^\w]+/g, '-').replace(/(^-|-$)/g, ''),
            });
          };
        })()
      );
    }

    // ── Attributes ({.class #id}) ──────────────────────────────────────
    // Must load BEFORE heading anchors take effect, but apply after.
    // markdown-it-attrs should be applied before anchor so IDs are reused.
    if (opts.attributes) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-attrs');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin);
          };
        })()
      );
    }

    // ── Table of contents ──────────────────────────────────────────────
    if (opts.tableOfContents) {
      loaders.push(
        (async () => {
          const mod = await import('markdown-it-table-of-contents');
          const plugin = getPlugin(mod as unknown as Record<string, unknown>);
          return (md: MarkdownIt) => {
            md.use(plugin, {
              includeLevel: [1, 2, 3, 4],
              containerClass: 'ic-md-toc',
              listType: 'ul',
            });
          };
        })()
      );
    }

    // ── Mermaid diagrams (fence override) ──────────────────────────────
    // Must be added LAST so it can wrap any existing fence behavior
    // (e.g. highlight.js via md.options.highlight).
    if (opts.mermaid) {
      loaders.push(
        (async () => {
          return (md: MarkdownIt) => {
            md.renderer.rules.fence = (tokens, idx, options, _env, _self) => {
              const token = tokens[idx];
              const info = token.info ? md.utils.unescapeAll(token.info).trim() : '';
              const lang = info.split(/\s+/g)[0];

              // Mermaid block → placeholder div (rendered in post-render $effect)
              if (lang.toLowerCase() === 'mermaid') {
                const source = encodeURIComponent(token.content);
                return `<div class="ic-md-mermaid" data-source="${source}"></div>\n`;
              }

              // Default fence rendering (replicates markdown-it built-in behavior)
              let highlighted = '';
              if (options.highlight) {
                highlighted = options.highlight(token.content, lang, '') || md.utils.escapeHtml(token.content);
              } else {
                highlighted = md.utils.escapeHtml(token.content);
              }
              if (highlighted.indexOf('<pre') === 0) {
                return highlighted + '\n';
              }
              const langClass = lang ? ` class="${options.langPrefix}${md.utils.escapeHtml(lang)}"` : '';
              return `<pre><code${langClass}>${highlighted}</code></pre>\n`;
            };
          };
        })()
      );
    }

    // Resolve all loaders in parallel, then apply in order
    const appliers = await Promise.all(loaders);
    for (const apply of appliers) {
      apply(instance);
    }

    // ── Safety: disable link navigation ───────────────────────────────
    // Override link renderer to remove target="_blank" and add rel safety.
    // In MATLAB's uihtml, link clicks must be prevented entirely (done via
    // onclick handler on the container element).
    const defaultLinkOpen = instance.renderer.rules.link_open;
    instance.renderer.rules.link_open = (tokens, idx, options, env, self) => {
      // Remove target attribute if any plugin added it
      const targetIdx = tokens[idx].attrIndex('target');
      if (targetIdx >= 0) tokens[idx].attrs!.splice(targetIdx, 1);
      if (defaultLinkOpen) {
        return defaultLinkOpen(tokens, idx, options, env, self);
      }
      return self.renderToken(tokens, idx, options);
    };

    return instance;
  }

  // ─── Image resolution (MATLAB fetches URLs + local file paths) ───────
  let contentEl: HTMLElement;
  const imageCache = new Map<string, string>(); // src → dataUri
  const pendingImages = new Set<string>();

  /** True if src needs MATLAB to resolve (URL or absolute file path). */
  function needsResolve(src: string): boolean {
    if (src.startsWith('http://') || src.startsWith('https://')) return true;
    if (src.startsWith('/')) return true;             // Unix absolute
    if (/^[A-Za-z]:[/\\]/.test(src)) return true;    // Windows absolute
    return false;
  }

  // After each render, find <img> with external/file src and resolve via MATLAB
  $effect(() => {
    // Read `rendered` to establish dependency (re-run when markdown changes)
    rendered;
    if (!contentEl || !request) return;

    // Run after DOM update
    requestAnimationFrame(() => {
      const imgs = contentEl.querySelectorAll<HTMLImageElement>('img[src]');
      for (const img of imgs) {
        const src = img.getAttribute('src') ?? '';
        if (!needsResolve(src)) continue;

        // Already resolved
        if (imageCache.has(src)) {
          img.src = imageCache.get(src)!;
          continue;
        }

        // Already fetching
        if (pendingImages.has(src)) continue;
        pendingImages.add(src);

        request('fetchImage', { url: src })
          .then((res) => {
            if (res.success && res.data) {
              const asset = (res.data as { asset: AssetData }).asset;
              const dataUri = resolveAssetAsDataUri(asset);
              imageCache.set(src, dataUri);
              // Apply to all matching images currently in the DOM
              contentEl?.querySelectorAll<HTMLImageElement>(`img[src="${CSS.escape(src)}"]`)
                .forEach((el) => { el.src = dataUri; });
            }
          })
          .catch(() => { /* image fetch failed — leave broken */ })
          .finally(() => { pendingImages.delete(src); });
      }
    });
  });

  // ─── Mermaid post-render (replace placeholders with SVGs) ───────────
  $effect(() => {
    rendered; // re-run when markdown changes
    if (!contentEl || !mermaid) return;

    requestAnimationFrame(() => {
      const blocks = contentEl.querySelectorAll<HTMLDivElement>('.ic-md-mermaid[data-source]');
      for (const block of blocks) {
        // Skip already-rendered blocks
        if (block.querySelector('svg')) continue;

        const source = decodeURIComponent(block.dataset.source ?? '');
        if (!source) continue;

        // Show loading state
        block.textContent = 'Rendering…';

        renderMermaid(source, contentEl).then((result) => {
          if (result.ok) {
            block.innerHTML = result.svg;
          } else {
            block.textContent = result.message;
            block.classList.add('ic-md-mermaid--error');
          }
        });
      }
    });
  });

  // Intercept link clicks:
  //  - Internal anchors (#fn1, #fnref1): let browser scroll
  //  - External URLs: send to MATLAB → opens system browser
  function handleClick(e: MouseEvent) {
    const link = (e.target as HTMLElement).closest('a');
    if (!link) return;

    const href = link.getAttribute('href') ?? '';
    if (href.startsWith('#')) {
      // Internal anchor — let the browser scroll to the target
      return;
    }

    e.preventDefault();
    e.stopPropagation();

    // Open external link via MATLAB's system browser
    if (request && (href.startsWith('http://') || href.startsWith('https://'))) {
      request('openLink', { url: href });
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-md"
  class:ic-md--wrap={lineWrapping}
  style:height={toSize(height)}
  onclick={handleClick}
>
  <div class="ic-md__content" bind:this={contentEl}>
    {@html rendered}
  </div>
</div>

<style>
  /* ═══════════════════════════════════════════════════════════════════════
     Block — container chrome (Industrial Flat)
     ═══════════════════════════════════════════════════════════════════════ */
  .ic-md {
    position: relative;
    display: flex;
    flex-direction: column;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: clip;
    /* Flex child: allow shrinking below content size */
    min-width: 0;
    min-height: 0;
  }

  /* ── Scrollable content area ─────────────────────────────────────────── */
  .ic-md__content {
    flex: 1;
    overflow: auto;
    padding: 16px 20px;
    color: var(--ic-foreground);
    font-size: 14px;
    line-height: 1.6;
  }

  .ic-md--wrap .ic-md__content {
    word-wrap: break-word;
    overflow-wrap: break-word;
  }

  /* ═══════════════════════════════════════════════════════════════════════
     Typography — rendered markdown content
     All rules use :global() because {@html} injects un-scoped DOM nodes.
     Parent selector .ic-md__content keeps them contained.
     ═══════════════════════════════════════════════════════════════════════ */

  /* ── Headings ────────────────────────────────────────────────────────── */
  .ic-md__content :global(h1),
  .ic-md__content :global(h2),
  .ic-md__content :global(h3),
  .ic-md__content :global(h4),
  .ic-md__content :global(h5),
  .ic-md__content :global(h6) {
    color: var(--ic-foreground);
    font-weight: 600;
    line-height: 1.25;
    margin: 1.5em 0 0.5em;
    letter-spacing: -0.01em;
  }

  .ic-md__content :global(h1:first-child),
  .ic-md__content :global(h2:first-child),
  .ic-md__content :global(h3:first-child) {
    margin-top: 0;
  }

  .ic-md__content :global(h1) { font-size: 1.75em; border-bottom: 1px solid var(--ic-border); padding-bottom: 0.3em; }
  .ic-md__content :global(h2) { font-size: 1.4em; border-bottom: 1px solid var(--ic-border); padding-bottom: 0.25em; }
  .ic-md__content :global(h3) { font-size: 1.15em; }
  .ic-md__content :global(h4) { font-size: 1em; }
  .ic-md__content :global(h5) { font-size: 0.9em; }
  .ic-md__content :global(h6) { font-size: 0.85em; color: var(--ic-muted-foreground); }

  /* ── Paragraphs & inline ─────────────────────────────────────────────── */
  .ic-md__content :global(p) {
    margin: 0.75em 0;
  }

  .ic-md__content :global(strong) {
    font-weight: 600;
    color: var(--ic-foreground);
  }

  .ic-md__content :global(a) {
    color: var(--ic-primary);
    text-decoration: none;
    cursor: default;
  }

  .ic-md__content :global(a:hover) {
    text-decoration: underline;
  }

  /* ── Inline code ─────────────────────────────────────────────────────── */
  .ic-md__content :global(code) {
    font-family: ui-monospace, 'Cascadia Code', 'Source Code Pro', Menlo, monospace;
    font-size: 0.85em;
    background-color: var(--ic-secondary);
    padding: 0.15em 0.4em;
    border-radius: 2px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
  }

  /* ── Code blocks (fenced) ────────────────────────────────────────────── */
  .ic-md__content :global(pre) {
    background-color: var(--ic-secondary);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    padding: 12px 16px;
    overflow-x: auto;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
    margin: 1em 0;
  }

  .ic-md__content :global(pre code) {
    background: none;
    padding: 0;
    box-shadow: none;
    font-size: 0.85em;
    line-height: 1.5;
  }

  /* ── highlight.js theme (Industrial Flat) ────────────────────────────── */
  .ic-md__content :global(.hljs-keyword),
  .ic-md__content :global(.hljs-selector-tag),
  .ic-md__content :global(.hljs-built_in) {
    color: var(--ic-primary);
    font-weight: 600;
  }

  .ic-md__content :global(.hljs-string),
  .ic-md__content :global(.hljs-addition) {
    color: var(--ic-success);
  }

  .ic-md__content :global(.hljs-comment),
  .ic-md__content :global(.hljs-quote) {
    color: var(--ic-muted-foreground);
    font-style: italic;
  }

  .ic-md__content :global(.hljs-number),
  .ic-md__content :global(.hljs-literal) {
    color: #d19a66;
  }

  .ic-md__content :global(.hljs-title),
  .ic-md__content :global(.hljs-section),
  .ic-md__content :global(.hljs-title.function_) {
    color: #61afef;
  }

  .ic-md__content :global(.hljs-type),
  .ic-md__content :global(.hljs-template-variable) {
    color: #e5c07b;
  }

  .ic-md__content :global(.hljs-variable),
  .ic-md__content :global(.hljs-attr) {
    color: var(--ic-foreground);
  }

  .ic-md__content :global(.hljs-deletion) {
    color: var(--ic-destructive);
  }

  .ic-md__content :global(.hljs-meta) {
    color: var(--ic-muted-foreground);
  }

  /* ── Blockquotes ─────────────────────────────────────────────────────── */
  .ic-md__content :global(blockquote) {
    margin: 1em 0;
    padding: 0.5em 1em;
    border-left: 3px solid var(--ic-primary);
    background-color: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    border-radius: 0;
  }

  .ic-md__content :global(blockquote p) {
    margin: 0.25em 0;
  }

  /* ── Lists ───────────────────────────────────────────────────────────── */
  .ic-md__content :global(ul),
  .ic-md__content :global(ol) {
    margin: 0.75em 0;
    padding-left: 1.5em;
  }

  .ic-md__content :global(li) {
    margin: 0.25em 0;
  }

  .ic-md__content :global(li > p) {
    margin: 0.25em 0;
  }

  /* ── Task lists ──────────────────────────────────────────────────────── */
  .ic-md__content :global(.task-list-item) {
    list-style: none;
    margin-left: -1.5em;
    padding-left: 0;
  }

  .ic-md__content :global(.task-list-item-checkbox) {
    margin-right: 0.4em;
    vertical-align: middle;
    accent-color: var(--ic-primary);
  }

  /* ── Horizontal rule ─────────────────────────────────────────────────── */
  .ic-md__content :global(hr) {
    border: none;
    border-top: 1px solid var(--ic-border);
    margin: 1.5em 0;
  }

  /* ── Tables ──────────────────────────────────────────────────────────── */
  .ic-md__content :global(table) {
    border-collapse: collapse;
    width: 100%;
    margin: 1em 0;
    font-size: 0.85em;
  }

  .ic-md__content :global(th) {
    background-color: var(--ic-secondary);
    font-weight: 600;
    text-align: left;
    padding: 6px 12px;
    border: 1px solid var(--ic-border);
    box-shadow: inset 0 -1px 2px rgba(0, 0, 0, 0.06);
  }

  .ic-md__content :global(td) {
    padding: 6px 12px;
    border: 1px solid var(--ic-border);
  }

  .ic-md__content :global(tr:nth-child(even)) {
    background-color: var(--ic-secondary);
  }

  /* ── Links ───────────────────────────────────────────────────────────── */
  .ic-md__content :global(a) {
    color: var(--ic-primary);
    text-decoration: none;
    cursor: pointer;
  }

  .ic-md__content :global(a:hover) {
    text-decoration: underline;
  }

  /* ── Images ──────────────────────────────────────────────────────────── */
  .ic-md__content :global(img) {
    max-width: 100%;
    height: auto;
    border-radius: 2px;
    border: 1px solid var(--ic-border);
  }

  /* ── Footnotes ───────────────────────────────────────────────────────── */
  .ic-md__content :global(.footnotes-sep) {
    border-top: 1px solid var(--ic-border);
    margin-top: 2em;
  }

  .ic-md__content :global(.footnotes) {
    font-size: 0.85em;
    color: var(--ic-muted-foreground);
  }

  .ic-md__content :global(.footnote-ref a),
  .ic-md__content :global(.footnote-backref) {
    color: var(--ic-primary);
    text-decoration: none;
    font-weight: 600;
  }

  /* ── Mark / highlight ────────────────────────────────────────────────── */
  /* No color-mix() — Chromium 104 doesn't support it. Use rgba fallback. */
  .ic-md__content :global(mark) {
    background-color: rgba(234, 179, 8, 0.25);
    color: var(--ic-foreground);
    padding: 0.1em 0.2em;
    border-radius: 2px;
  }

  /* ── Subscript / Superscript ─────────────────────────────────────────── */
  .ic-md__content :global(sub),
  .ic-md__content :global(sup) {
    font-size: 0.75em;
  }

  /* ── Custom containers / admonitions ─────────────────────────────────── */
  /* No color-mix() — use rgba fallbacks for Chromium 104 */
  .ic-md__content :global(.ic-md-container) {
    margin: 1em 0;
    padding: 0.75em 1em;
    border-left: 3px solid var(--ic-border);
    border-radius: 0 2px 2px 0;
  }

  .ic-md__content :global(.ic-md-container__title) {
    margin: 0 0 0.25em;
    font-weight: 700;
    font-size: 0.85em;
    letter-spacing: 0.03em;
    text-transform: uppercase;
  }

  .ic-md__content :global(.ic-md-container--warning) {
    border-left-color: var(--ic-warning);
    background-color: rgba(234, 179, 8, 0.08);
  }
  .ic-md__content :global(.ic-md-container--warning .ic-md-container__title) {
    color: var(--ic-warning);
  }

  .ic-md__content :global(.ic-md-container--info) {
    border-left-color: var(--ic-info);
    background-color: rgba(59, 130, 246, 0.08);
  }
  .ic-md__content :global(.ic-md-container--info .ic-md-container__title) {
    color: var(--ic-info);
  }

  .ic-md__content :global(.ic-md-container--tip) {
    border-left-color: var(--ic-success);
    background-color: rgba(34, 197, 94, 0.08);
  }
  .ic-md__content :global(.ic-md-container--tip .ic-md-container__title) {
    color: var(--ic-success);
  }

  .ic-md__content :global(.ic-md-container--danger) {
    border-left-color: var(--ic-destructive);
    background-color: rgba(239, 68, 68, 0.08);
  }
  .ic-md__content :global(.ic-md-container--danger .ic-md-container__title) {
    color: var(--ic-destructive);
  }

  /* ── Definition lists ────────────────────────────────────────────────── */
  .ic-md__content :global(dl) {
    margin: 0.75em 0;
  }

  .ic-md__content :global(dt) {
    font-weight: 600;
    margin-top: 0.5em;
  }

  .ic-md__content :global(dd) {
    margin-left: 1.5em;
    margin-bottom: 0.25em;
    color: var(--ic-muted-foreground);
  }

  /* ── Abbreviations ──────────────────────────────────────────────────── */
  .ic-md__content :global(abbr[title]) {
    text-decoration: underline dotted var(--ic-muted-foreground);
    cursor: help;
  }

  /* ── Insert (underline) ─────────────────────────────────────────────── */
  .ic-md__content :global(ins) {
    text-decoration: underline;
    text-decoration-color: var(--ic-primary);
    text-underline-offset: 2px;
  }

  /* ── Heading anchors ────────────────────────────────────────────────── */
  .ic-md__content :global(h1[id]),
  .ic-md__content :global(h2[id]),
  .ic-md__content :global(h3[id]),
  .ic-md__content :global(h4[id]),
  .ic-md__content :global(h5[id]),
  .ic-md__content :global(h6[id]) {
    scroll-margin-top: 0.5em;
  }

  /* ── Table of contents ──────────────────────────────────────────────── */
  .ic-md__content :global(.ic-md-toc) {
    background-color: var(--ic-secondary);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    padding: 0.75em 1em;
    margin: 1em 0;
  }

  .ic-md__content :global(.ic-md-toc ul) {
    list-style: none;
    padding-left: 1em;
    margin: 0;
  }

  .ic-md__content :global(.ic-md-toc > ul) {
    padding-left: 0;
  }

  .ic-md__content :global(.ic-md-toc li) {
    margin: 0.15em 0;
    font-size: 0.9em;
  }

  .ic-md__content :global(.ic-md-toc a) {
    color: var(--ic-muted-foreground);
  }

  .ic-md__content :global(.ic-md-toc a:hover) {
    color: var(--ic-primary);
  }

  /* ── KaTeX overrides ─────────────────────────────────────────────────── */
  .ic-md__content :global(.katex) {
    font-size: 1em;
  }

  .ic-md__content :global(.katex-display) {
    margin: 1em 0;
    overflow-x: auto;
    overflow-y: clip;
  }

  /* ── Mermaid diagrams (static, inline) ─────────────────────────────── */
  .ic-md__content :global(.ic-md-mermaid) {
    margin: 1em 0;
    padding: 16px;
    background-color: var(--ic-muted);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow-x: auto;
    text-align: center;
    min-height: 40px;
    color: var(--ic-muted-foreground);
    font-size: 12px;
  }

  .ic-md__content :global(.ic-md-mermaid svg) {
    max-width: 100%;
    height: auto;
  }

  .ic-md__content :global(.ic-md-mermaid--error) {
    color: var(--ic-destructive);
    white-space: pre-wrap;
    word-break: break-word;
  }
</style>
