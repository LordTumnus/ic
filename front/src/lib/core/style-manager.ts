/**
 * StyleManager - Singleton that manages instance-level CSS rules.
 * Uses Constructable Stylesheets for pseudo-element support and performance.
 */

class StyleManager {
  private static _instance: StyleManager | null = null;
  private sheet: CSSStyleSheet | null = null;

  /** Maps "componentId:selector" → rule index in sheet.cssRules */
  private ruleIndices = new Map<string, number>();

  private constructor() {}

  static get instance(): StyleManager {
    if (!StyleManager._instance) {
      StyleManager._instance = new StyleManager();
    }
    return StyleManager._instance;
  }

  private getSheet(): CSSStyleSheet {
    if (!this.sheet) {
      this.sheet = new CSSStyleSheet();
      document.adoptedStyleSheets = [...document.adoptedStyleSheets, this.sheet];
    }
    return this.sheet;
  }

  /** Set styles for a selector within a component. */
  setStyles(componentId: string, selector: string, styles: Record<string, string>): void {
    const key = `${componentId}:${selector}`;
    const scopedSelector = selector
      ? `#${CSS.escape(componentId)} ${selector}`
      : `#${CSS.escape(componentId)}`;
    const cssText = Object.entries(styles)
      .map(([prop, value]) => `${prop.replace(/_/g, '-')}: ${value}`)
      .join('; ');
    const rule = `${scopedSelector} { ${cssText} }`;

    if (this.ruleIndices.has(key)) {
      this.deleteRule(key);
    }

    const sheet = this.getSheet();
    const index = sheet.insertRule(rule, sheet.cssRules.length);
    this.ruleIndices.set(key, index);
  }

  /** Clear a specific style rule. */
  clearStyle(componentId: string, selector: string): void {
    this.deleteRule(`${componentId}:${selector}`);
  }

  /** Clear all style rules for a component. */
  clearStyles(componentId: string): void {
    const prefix = `${componentId}:`;
    const keysToDelete = [...this.ruleIndices.keys()].filter(k => k.startsWith(prefix));

    // Delete in reverse index order to avoid shifting issues
    keysToDelete
      .sort((a, b) => this.ruleIndices.get(b)! - this.ruleIndices.get(a)!)
      .forEach(key => this.deleteRule(key));
  }

  private deleteRule(key: string): void {
    const index = this.ruleIndices.get(key);
    if (index === undefined) return;

    this.getSheet().deleteRule(index);
    this.ruleIndices.delete(key);

    // Adjust indices for rules that shifted down
    this.ruleIndices.forEach((ruleIndex, k) => {
      if (ruleIndex > index) {
        this.ruleIndices.set(k, ruleIndex - 1);
      }
    });
  }

  /** Reset state. For testing only. */
  _reset(): void {
    if (this.sheet) {
      this.sheet.replaceSync('');
      document.adoptedStyleSheets = document.adoptedStyleSheets.filter(s => s !== this.sheet);
      this.sheet = null;
    }
    this.ruleIndices.clear();
  }
}

export default StyleManager;
