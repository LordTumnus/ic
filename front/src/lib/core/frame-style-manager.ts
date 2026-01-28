/**
 * FrameStyleManager - Singleton that manages global component styles.
 *
 * Uses Constructable Stylesheets to inject type-scoped CSS rules.
 * Theme variables are handled separately via Frame.svelte's inline styles.
 */

class FrameStyleManager {
  private static _instance: FrameStyleManager | null = null;

  private sheet: CSSStyleSheet | null = null;

  /** Maps "type:selector" → rule index in sheet.cssRules */
  private ruleIndices = new Map<string, number>();

  private constructor() {}

  static get instance(): FrameStyleManager {
    if (!FrameStyleManager._instance) {
      FrameStyleManager._instance = new FrameStyleManager();
    }
    return FrameStyleManager._instance;
  }

  /** Initialize the global stylesheet. Called once when Frame mounts. */
  init(_frameId: string = 'ic-frame'): void {
    if (this.sheet) return;

    this.sheet = new CSSStyleSheet();
    document.adoptedStyleSheets = [this.sheet, ...document.adoptedStyleSheets];
  }

  /** Set global styles for a component type. */
  setGlobalStyle(type: string, selector: string, styles: Record<string, string>): void {
    if (!this.sheet) return;

    const key = `${type}:${selector}`;
    const scopedSelector = `[data-ic-type="${type}"] ${selector}`;
    const cssText = Object.entries(styles)
      .map(([prop, value]) => `${prop}: ${value}`)
      .join('; ');
    const rule = `${scopedSelector} { ${cssText} }`;

    if (this.ruleIndices.has(key)) {
      this.deleteRule(key);
    }

    const index = this.sheet.insertRule(rule, this.sheet.cssRules.length);
    this.ruleIndices.set(key, index);
  }

  /** Clear a specific global style rule. */
  clearGlobalStyle(type: string, selector: string): void {
    this.deleteRule(`${type}:${selector}`);
  }

  /** Clear all global style rules for a component type. */
  clearGlobalStyles(type: string): void {
    const prefix = `${type}:`;
    const keysToDelete = [...this.ruleIndices.keys()].filter(k => k.startsWith(prefix));

    keysToDelete
      .sort((a, b) => this.ruleIndices.get(b)! - this.ruleIndices.get(a)!)
      .forEach(key => this.deleteRule(key));
  }

  /** Clear all global style rules. */
  clearAllGlobalStyles(): void {
    if (!this.sheet) return;
    this.sheet.replaceSync('');
    this.ruleIndices.clear();
  }

  private deleteRule(key: string): void {
    if (!this.sheet) return;

    const index = this.ruleIndices.get(key);
    if (index === undefined) return;

    this.sheet.deleteRule(index);
    this.ruleIndices.delete(key);

    this.ruleIndices.forEach((ruleIndex, k) => {
      if (ruleIndex > index) {
        this.ruleIndices.set(k, ruleIndex - 1);
      }
    });
  }

  /** Reset state. For testing only. */
  _reset(): void {
    if (this.sheet) {
      document.adoptedStyleSheets = document.adoptedStyleSheets.filter(s => s !== this.sheet);
      this.sheet = null;
    }
    this.ruleIndices.clear();
  }
}

export default FrameStyleManager;
