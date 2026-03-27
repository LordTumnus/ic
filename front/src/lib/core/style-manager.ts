/**
 * StyleManager - Singleton that manages instance-level CSS rules and keyframes.
 * Uses Constructable Stylesheets for pseudo-element support and performance.
 */

class StyleManager {
  private static _instance: StyleManager | null = null;
  private sheet: CSSStyleSheet | null = null;

  /** Maps "componentId:selector" → rule index in sheet.cssRules */
  private ruleIndices = new Map<string, number>();

  /** Maps "@kf:name" → rule index for @keyframes rules */
  private keyframeIndices = new Map<string, number>();

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

  // ── Instance styles ────────────────────────────────────────────────

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

  /** Clear all style rules and keyframes for a component. */
  clearStyles(componentId: string): void {
    const prefix = `${componentId}:`;
    const keysToDelete = [...this.ruleIndices.keys()].filter(k => k.startsWith(prefix));

    // Delete in reverse index order to avoid shifting issues
    keysToDelete
      .sort((a, b) => this.ruleIndices.get(b)! - this.ruleIndices.get(a)!)
      .forEach(key => this.deleteRule(key));

    // Also clear any keyframes registered by this component
    this.clearKeyframes(componentId);
  }

  // ── Keyframes ──────────────────────────────────────────────────────

  /** Insert or replace a @keyframes rule. Name is used as-is (global). */
  setKeyframes(componentId: string, name: string, frames: Record<string, Record<string, string>>): void {
    const key = `${componentId}:@kf:${name}`;

    // Build @keyframes CSS text
    const frameEntries = Object.entries(frames).map(([stop, props]) => {
      // Convert struct field names: "from"/"to" pass through,
      // "p0" → "0%", "p50" → "50%", "p100" → "100%"
      let cssStop = stop;
      const pMatch = stop.match(/^p(\d+)$/);
      if (pMatch) {
        cssStop = `${pMatch[1]}%`;
      }
      const cssText = Object.entries(props)
        .map(([prop, value]) => `${prop.replace(/_/g, '-')}: ${value}`)
        .join('; ');
      return `${cssStop} { ${cssText} }`;
    }).join(' ');

    const rule = `@keyframes ${name} { ${frameEntries} }`;

    if (this.keyframeIndices.has(key)) {
      this.deleteKeyframeRule(key);
    }

    const sheet = this.getSheet();
    const index = sheet.insertRule(rule, sheet.cssRules.length);
    this.keyframeIndices.set(key, index);
  }

  /** Remove a @keyframes rule registered by a component. */
  removeKeyframes(componentId: string, name: string): void {
    this.deleteKeyframeRule(`${componentId}:@kf:${name}`);
  }

  /** Clear all @keyframes rules for a component. */
  clearKeyframes(componentId: string): void {
    const prefix = `${componentId}:@kf:`;
    const keysToDelete = [...this.keyframeIndices.keys()].filter(k => k.startsWith(prefix));
    keysToDelete
      .sort((a, b) => this.keyframeIndices.get(b)! - this.keyframeIndices.get(a)!)
      .forEach(key => this.deleteKeyframeRule(key));
  }

  // ── Internal ───────────────────────────────────────────────────────

  private deleteRule(key: string): void {
    const index = this.ruleIndices.get(key);
    if (index === undefined) return;

    this.getSheet().deleteRule(index);
    this.ruleIndices.delete(key);

    // Adjust indices for rules that shifted down (both maps share one sheet)
    this.ruleIndices.forEach((ruleIndex, k) => {
      if (ruleIndex > index) {
        this.ruleIndices.set(k, ruleIndex - 1);
      }
    });
    this.keyframeIndices.forEach((ruleIndex, k) => {
      if (ruleIndex > index) {
        this.keyframeIndices.set(k, ruleIndex - 1);
      }
    });
  }

  private deleteKeyframeRule(key: string): void {
    const index = this.keyframeIndices.get(key);
    if (index === undefined) return;

    this.getSheet().deleteRule(index);
    this.keyframeIndices.delete(key);

    // Adjust indices in both maps
    this.ruleIndices.forEach((ruleIndex, k) => {
      if (ruleIndex > index) {
        this.ruleIndices.set(k, ruleIndex - 1);
      }
    });
    this.keyframeIndices.forEach((ruleIndex, k) => {
      if (ruleIndex > index) {
        this.keyframeIndices.set(k, ruleIndex - 1);
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
    this.keyframeIndices.clear();
  }
}

export default StyleManager;
