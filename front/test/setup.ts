/**
 * Vitest test setup file.
 *
 * Configures the test environment:
 * - Polyfills for jsdom (adoptedStyleSheets)
 * - Resets singletons between tests for isolation
 * - Provides common test utilities
 */

import { beforeEach, afterEach } from 'vitest';
import Bridge from '../src/lib/core/bridge';
import Registry from '../src/lib/core/registry';
import StyleManager from '../src/lib/core/style-manager';
import FrameStyleManager from '../src/lib/core/frame-style-manager';

// Polyfill CSS.escape (not available in jsdom)
if (typeof CSS === 'undefined' || !CSS.escape) {
  (globalThis as any).CSS = {
    escape: (str: string) => str.replace(/([^\w-])/g, '\\$1')
  };
}

// Polyfill for Constructable Stylesheets (not supported in jsdom)
if (!document.adoptedStyleSheets) {
  Object.defineProperty(document, 'adoptedStyleSheets', {
    value: [],
    writable: true,
    configurable: true
  });
}

// Mock CSSStyleSheet if not available
if (typeof CSSStyleSheet === 'undefined' || !CSSStyleSheet.prototype.replaceSync) {
  (globalThis as any).CSSStyleSheet = class MockCSSStyleSheet {
    cssRules: { cssText: string }[] = [];

    insertRule(rule: string, index?: number): number {
      const idx = index ?? this.cssRules.length;
      this.cssRules.splice(idx, 0, { cssText: rule });
      return idx;
    }

    deleteRule(index: number): void {
      this.cssRules.splice(index, 1);
    }

    replaceSync(css: string): void {
      this.cssRules = css ? [{ cssText: css }] : [];
    }
  };
}

// Reset singletons before each test to ensure test isolation
beforeEach(() => {
  Bridge.instance._reset();
  Registry.instance._reset();
  StyleManager.instance._reset();
  FrameStyleManager.instance._reset();
});

// Cleanup after each test
afterEach(() => {
  // Clear any remaining DOM content
  document.body.innerHTML = '';
  // Reset adoptedStyleSheets
  document.adoptedStyleSheets = [];
});
