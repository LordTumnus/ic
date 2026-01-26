/**
 * Vitest test setup file.
 *
 * Configures the test environment:
 * - Resets singletons between tests for isolation
 * - Provides common test utilities
 */

import { beforeEach, afterEach } from 'vitest';
import Bridge from '../src/lib/core/bridge';
import Registry from '../src/lib/core/registry';

// Reset singletons before each test to ensure test isolation
beforeEach(() => {
  Bridge.instance._reset();
  Registry.instance._reset();
});

// Cleanup after each test
afterEach(() => {
  // Clear any remaining DOM content
  document.body.innerHTML = '';
});
