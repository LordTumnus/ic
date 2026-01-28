/**
 * FrameStyleManager - Singleton that manages frame-level CSS.
 * Handles theme variables (CSS custom properties) and global component styles.
 */

class FrameStyleManager {
  private static _instance: FrameStyleManager | null = null;

  private themeSheet: CSSStyleSheet | null = null;
  private globalSheet: CSSStyleSheet | null = null;
  private frameId = 'ic-frame';

  /** Maps "type:selector" → rule index in globalSheet.cssRules */
  private globalRuleIndices = new Map<string, number>();

  private constructor() {}

  static get instance(): FrameStyleManager {
    if (!FrameStyleManager._instance) {
      FrameStyleManager._instance = new FrameStyleManager();
    }
    return FrameStyleManager._instance;
  }

  /** Initialize sheets. Called once when Frame mounts. */
  init(frameId: string = 'ic-frame'): void {
    if (this.themeSheet) return;

    this.frameId = frameId;
    this.themeSheet = new CSSStyleSheet();
    this.globalSheet = new CSSStyleSheet();

    // Prepend both sheets: [theme, global, ...existing]
    document.adoptedStyleSheets = [
      this.themeSheet,
      this.globalSheet,
      ...document.adoptedStyleSheets
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // Theme
  // ─────────────────────────────────────────────────────────────

  /** Set theme variables. Replaces all existing theme rules. */
  setTheme(variables: Record<string, string>): void {
    if (!this.themeSheet) return;

    const cssText = Object.entries(variables)
      .map(([prop, value]) => `${prop}: ${value}`)
      .join('; ');

    const selector = `#${CSS.escape(this.frameId)}`;
    this.themeSheet.replaceSync(`${selector} { ${cssText} }`);
  }

  /** Set color scheme (controls light-dark() resolution). */
  setColorScheme(scheme: 'light' | 'dark' | 'system'): void {
    const frame = document.getElementById(this.frameId);
    if (!frame) return;

    if (scheme === 'system') {
      frame.removeAttribute('data-color-scheme');
    } else {
      frame.setAttribute('data-color-scheme', scheme);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Global Styles
  // ─────────────────────────────────────────────────────────────

  /** Set global styles for a component type. */
  setGlobalStyle(type: string, selector: string, styles: Record<string, string>): void {
    if (!this.globalSheet) return;

    const key = `${type}:${selector}`;
    const scopedSelector = `[data-ic-type="${type}"] ${selector}`;
    const cssText = Object.entries(styles)
      .map(([prop, value]) => `${prop}: ${value}`)
      .join('; ');
    const rule = `${scopedSelector} { ${cssText} }`;

    if (this.globalRuleIndices.has(key)) {
      this.deleteGlobalRule(key);
    }

    const index = this.globalSheet.insertRule(rule, this.globalSheet.cssRules.length);
    this.globalRuleIndices.set(key, index);
  }

  /** Clear a specific global style rule. */
  clearGlobalStyle(type: string, selector: string): void {
    this.deleteGlobalRule(`${type}:${selector}`);
  }

  /** Clear all global style rules for a component type. */
  clearGlobalStyles(type: string): void {
    const prefix = `${type}:`;
    const keysToDelete = [...this.globalRuleIndices.keys()].filter(k => k.startsWith(prefix));

    keysToDelete
      .sort((a, b) => this.globalRuleIndices.get(b)! - this.globalRuleIndices.get(a)!)
      .forEach(key => this.deleteGlobalRule(key));
  }

  /** Clear all global style rules. */
  clearAllGlobalStyles(): void {
    if (!this.globalSheet) return;
    this.globalSheet.replaceSync('');
    this.globalRuleIndices.clear();
  }

  // ─────────────────────────────────────────────────────────────
  // Private
  // ─────────────────────────────────────────────────────────────

  private deleteGlobalRule(key: string): void {
    if (!this.globalSheet) return;

    const index = this.globalRuleIndices.get(key);
    if (index === undefined) return;

    this.globalSheet.deleteRule(index);
    this.globalRuleIndices.delete(key);

    this.globalRuleIndices.forEach((ruleIndex, k) => {
      if (ruleIndex > index) {
        this.globalRuleIndices.set(k, ruleIndex - 1);
      }
    });
  }

  /** Reset state. For testing only. */
  _reset(): void {
    if (this.themeSheet || this.globalSheet) {
      document.adoptedStyleSheets = document.adoptedStyleSheets.filter(
        s => s !== this.themeSheet && s !== this.globalSheet
      );
      this.themeSheet = null;
      this.globalSheet = null;
    }
    this.globalRuleIndices.clear();
  }
}

export default FrameStyleManager;
