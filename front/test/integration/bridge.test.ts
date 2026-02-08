/**
 * Integration tests for the MATLAB-Svelte bridge.
 *
 * Tests the full communication flow between MATLAB and Svelte components:
 * - Component insertion and removal
 * - Bidirectional property synchronization
 * - Events (Svelte → MATLAB)
 * - Methods (MATLAB → Svelte with response)
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { tick } from 'svelte';
import Bridge from '$lib/core/bridge';
import Registry from '$lib/core/registry';
import FrameComponent from '$lib/core/frame-component.svelte';
import Frame from '$lib/components/core/frame/Frame.svelte';
import MockMatlabHTML from '../mocks/matlab-html';
import type {
  ComponentDefinition,
  InsertEventData,
  RemoveEventData,
  StyleEventData,
  ClearStyleEventData,
  GlobalStyleEventData,
  ClearGlobalStyleEventData,
  ClearGlobalStylesEventData,
  ThemeEventData
} from '$lib/types';

// Counter for generating unique IDs across tests
let testIdCounter = 0;
function uniqueId(prefix: string): string {
  return `${prefix}-${++testIdCounter}`;
}

/**
 * Helper to create a standard TestComponent definition.
 */
function createTestComponentDefinition(
  id: string,
  overrides: Partial<ComponentDefinition> = {}
): ComponentDefinition {
  return {
    type: 'ic.test.TestComponent',
    id,
    props: [
      { name: 'label', value: 'Test Label' },
      { name: 'counter', value: 0 },
      { name: 'enabled', value: true },
    ],
    events: [
      { name: 'clicked' },
      { name: 'valueChanged' },
    ],
    methods: [
      { name: 'echo' },
      { name: 'incrementCounter' },
      { name: 'getState' },
    ],
    targets: ['default'],
    ...overrides,
  };
}

/**
 * Helper to create a TestStaticContainer definition with a static child.
 * The static child is a TestComponent with id "{containerId}-child".
 */
function createTestStaticContainerDefinition(
  id: string,
  childOverrides: Partial<ComponentDefinition> = {}
): ComponentDefinition {
  return {
    type: 'ic.test.TestStaticContainer',
    id,
    props: [
      { name: 'title', value: 'Test Static Container' },
      { name: 'childCounter', value: 0 },
    ],
    events: [],
    methods: [
      { name: 'getState' },
    ],
    targets: ['default'],
    staticChildren: [
      {
        component: createTestComponentDefinition(`${id}-child`, childOverrides),
        target: 'child',
      },
    ],
  };
}

/**
 * Helper to set up the bridge with a mock MATLAB element.
 * Returns the mock for test assertions.
 */
function setupBridge(): MockMatlabHTML {
  const mock = new MockMatlabHTML();
  const bridge = Bridge.instance;
  const registry = Registry.instance;

  // Create and register the Frame (root component)
  const frame = new FrameComponent(Frame as any);
  registry.register(frame);
  frame.mount(document.body);

  // Wire dispatcher and setup bridge
  bridge.setDispatcher((event) => registry.dispatch(event));
  bridge.setup(mock);

  return mock;
}

/**
 * Helper to wait for async operations (microtasks + DOM updates).
 * Uses polling to handle dynamic imports and nested async chains.
 */
async function flushAsync(): Promise<void> {
  // Multiple flushes to handle nested async operations (Factory.create, etc.)
  for (let i = 0; i < 10; i++) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    await tick();
  }
}

/**
 * Wait for a condition to become true, with polling.
 * Useful for waiting on dynamic imports and async component creation.
 */
async function waitFor(
  condition: () => boolean,
  { timeout = 1000, interval = 10 } = {}
): Promise<void> {
  const start = Date.now();
  while (!condition()) {
    if (Date.now() - start > timeout) {
      throw new Error('waitFor timeout exceeded');
    }
    await new Promise((resolve) => setTimeout(resolve, interval));
    await tick();
  }
}

describe('Bridge Integration', () => {
  let mock: MockMatlabHTML;

  beforeEach(() => {
    mock = setupBridge();
  });

  describe('Component Insertion', () => {
    it('should insert a component into the frame', async () => {
      const id = uniqueId('insert');
      const insertData: InsertEventData = {
        component: createTestComponentDefinition(id),
        target: 'default',
      };

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: insertData,
        id: uniqueId('evt'),
      });

      // Wait for dynamic import and registration to complete
      await waitFor(() => Registry.instance.has(id));

      // Component should be in the DOM
      const testComponent = document.querySelector('[data-testid="test-component"]');
      expect(testComponent).not.toBeNull();
    });

    it('should insert multiple components', async () => {
      const id1 = uniqueId('comp');
      const id2 = uniqueId('comp');

      // Insert first component
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id1, {
            props: [
              { name: 'label', value: 'Component 1' },
              { name: 'counter', value: 10 },
              { name: 'enabled', value: true },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      // Insert second component
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id2, {
            props: [
              { name: 'label', value: 'Component 2' },
              { name: 'counter', value: 20 },
              { name: 'enabled', value: true },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      // Wait for both components to be registered
      await waitFor(() => Registry.instance.has(id1) && Registry.instance.has(id2));

      const components = document.querySelectorAll('[data-testid="test-component"]');
      expect(components.length).toBe(2);
    });

    it('should render initial prop values', async () => {
      const id = uniqueId('props');
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id, {
            props: [
              { name: 'label', value: 'Hello MATLAB' },
              { name: 'counter', value: 42 },
              { name: 'enabled', value: true },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      // Wait for component to be registered and rendered
      await waitFor(() => Registry.instance.has(id));
      await flushAsync(); // Extra flush for DOM rendering

      const label = document.querySelector('[data-testid="label"]');
      const counter = document.querySelector('[data-testid="counter"]');

      expect(label?.textContent).toBe('Hello MATLAB');
      expect(counter?.textContent).toBe('42');
    });
  });

  describe('Component Removal', () => {
    it('should remove a component from the frame', async () => {
      const id = uniqueId('toRemove');

      // First insert a component
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();
      expect(Registry.instance.has(id)).toBe(true);

      // Now remove it
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@remove',
        data: { id } as RemoveEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Component should be deregistered
      expect(Registry.instance.has(id)).toBe(false);

      // Component should be removed from DOM
      const components = document.querySelectorAll('[data-testid="test-component"]');
      expect(components.length).toBe(0);
    });

    it('should only remove the specified component', async () => {
      const keepId = uniqueId('keep');
      const removeId = uniqueId('remove');

      // Insert two components
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(keepId),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(removeId),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Remove only one
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@remove',
        data: { id: removeId } as RemoveEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      expect(Registry.instance.has(keepId)).toBe(true);
      expect(Registry.instance.has(removeId)).toBe(false);

      const components = document.querySelectorAll('[data-testid="test-component"]');
      expect(components.length).toBe(1);
    });
  });

  describe('Property Synchronization', () => {
    it('should update props when MATLAB sends @prop events', async () => {
      const id = uniqueId('propTest');

      // Insert component
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Update label from MATLAB
      await mock.simulateEvent({
        component: id,
        name: '@prop/label',
        data: 'Updated from MATLAB',
        id: uniqueId('evt'),
      });

      await flushAsync();

      const label = document.querySelector('[data-testid="label"]');
      expect(label?.textContent).toBe('Updated from MATLAB');
    });

    it('should update counter prop from MATLAB', async () => {
      const id = uniqueId('counterTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Update counter from MATLAB
      await mock.simulateEvent({
        component: id,
        name: '@prop/counter',
        data: 99,
        id: uniqueId('evt'),
      });

      await flushAsync();

      const counter = document.querySelector('[data-testid="counter"]');
      expect(counter?.textContent).toBe('99');
    });

    it('should send prop changes to MATLAB when modified in Svelte', async () => {
      const id = uniqueId('syncTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Enable valueChanged event (events only fire when MATLAB has a listener)
      await mock.simulateEvent({
        component: id,
        name: '@listenEvent',
        data: 'valueChanged',
        id: uniqueId('evt'),
      });
      await flushAsync();
      mock.sentHistory = [];

      // Simulate user typing in the input field
      const input = document.querySelector('[data-testid="label-input"]') as HTMLInputElement;
      input.value = 'User typed this';
      input.dispatchEvent(new Event('input', { bubbles: true }));

      await flushAsync();

      // Should have sent valueChanged event to MATLAB
      const sentEvents = mock.sentHistory.flat();
      const valueChangedEvent = sentEvents.find(
        (e) => e.component === id && e.name === '@event/valueChanged'
      );
      expect(valueChangedEvent).toBeDefined();
      expect(valueChangedEvent?.data).toEqual({ field: 'label', value: 'User typed this' });
    });
  });

  describe('Events (Svelte → MATLAB)', () => {
    it('should send clicked event to MATLAB when button is clicked', async () => {
      const id = uniqueId('eventTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Enable clicked event (events only fire when MATLAB has a listener)
      await mock.simulateEvent({
        component: id,
        name: '@listenEvent',
        data: 'clicked',
        id: uniqueId('evt'),
      });
      await flushAsync();
      mock.sentHistory = [];

      // Click the button
      const button = document.querySelector('[data-testid="click-btn"]') as HTMLButtonElement;
      button.click();

      await flushAsync();

      const sentEvents = mock.sentHistory.flat();
      const clickEvent = sentEvents.find(
        (e) => e.component === id && e.name === '@event/clicked'
      );
      expect(clickEvent).toBeDefined();
      expect(clickEvent?.data).toHaveProperty('timestamp');
    });

    it('should send valueChanged event when counter is incremented via UI', async () => {
      const id = uniqueId('counterEventTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Enable valueChanged event (events only fire when MATLAB has a listener)
      await mock.simulateEvent({
        component: id,
        name: '@listenEvent',
        data: 'valueChanged',
        id: uniqueId('evt'),
      });
      await flushAsync();
      mock.sentHistory = [];

      // Click increment button
      const incrementBtn = document.querySelector('[data-testid="increment-btn"]') as HTMLButtonElement;
      incrementBtn.click();

      await flushAsync();

      const sentEvents = mock.sentHistory.flat();
      const valueChangedEvent = sentEvents.find(
        (e) => e.component === id && e.name === '@event/valueChanged'
      );
      expect(valueChangedEvent).toBeDefined();
      expect(valueChangedEvent?.data).toEqual({ field: 'counter', value: 1 });
    });
  });

  describe('Event Listener Gating', () => {
    it('should not send events when no @listenEvent has been received', async () => {
      const id = uniqueId('gateTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();
      mock.sentHistory = [];

      // Click the button — no @listenEvent was sent, so event should be suppressed
      const button = document.querySelector('[data-testid="click-btn"]') as HTMLButtonElement;
      button.click();

      await flushAsync();

      const sentEvents = mock.sentHistory.flat();
      const clickEvent = sentEvents.find(
        (e) => e.component === id && e.name === '@event/clicked'
      );
      expect(clickEvent).toBeUndefined();
    });

    it('should send events after @listenEvent is received', async () => {
      const id = uniqueId('listenTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Enable the clicked event
      await mock.simulateEvent({
        component: id,
        name: '@listenEvent',
        data: 'clicked',
        id: uniqueId('evt'),
      });
      await flushAsync();
      mock.sentHistory = [];

      // Click the button — event should now be sent
      const button = document.querySelector('[data-testid="click-btn"]') as HTMLButtonElement;
      button.click();

      await flushAsync();

      const sentEvents = mock.sentHistory.flat();
      const clickEvent = sentEvents.find(
        (e) => e.component === id && e.name === '@event/clicked'
      );
      expect(clickEvent).toBeDefined();
      expect(clickEvent?.data).toHaveProperty('timestamp');
    });

    it('should stop sending events after @unlistenEvent is received', async () => {
      const id = uniqueId('unlistenTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Enable then disable the clicked event
      await mock.simulateEvent({
        component: id,
        name: '@listenEvent',
        data: 'clicked',
        id: uniqueId('evt'),
      });
      await flushAsync();

      await mock.simulateEvent({
        component: id,
        name: '@unlistenEvent',
        data: 'clicked',
        id: uniqueId('evt'),
      });
      await flushAsync();
      mock.sentHistory = [];

      // Click the button — event should be suppressed again
      const button = document.querySelector('[data-testid="click-btn"]') as HTMLButtonElement;
      button.click();

      await flushAsync();

      const sentEvents = mock.sentHistory.flat();
      const clickEvent = sentEvents.find(
        (e) => e.component === id && e.name === '@event/clicked'
      );
      expect(clickEvent).toBeUndefined();
    });
  });

  describe('Methods (MATLAB → Svelte)', () => {
    it('should invoke echo method and return response', async () => {
      const id = uniqueId('methodTest');
      const methodCallId = uniqueId('method-call');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();
      mock.sentHistory = [];

      // Call echo method from MATLAB
      await mock.simulateEvent({
        component: id,
        name: 'echo',
        data: { message: 'Hello from MATLAB' },
        id: methodCallId,
      });

      await flushAsync();

      // Should have received response
      const sentEvents = mock.sentHistory.flat();
      const response = sentEvents.find(
        (e) => e.component === id && e.name === `@resp/${methodCallId}`
      );
      expect(response).toBeDefined();
      expect(response?.data).toEqual({
        success: true,
        data: { message: 'Hello from MATLAB' },
      });
    });

    it('should invoke incrementCounter method and return new value', async () => {
      const id = uniqueId('incTest');
      const methodCallId = uniqueId('method-call');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id, {
            props: [
              { name: 'label', value: 'Test' },
              { name: 'counter', value: 5 },
              { name: 'enabled', value: true },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();
      mock.sentHistory = [];

      // Call incrementCounter method
      await mock.simulateEvent({
        component: id,
        name: 'incrementCounter',
        data: null,
        id: methodCallId,
      });

      await flushAsync();

      // Check response
      const sentEvents = mock.sentHistory.flat();
      const response = sentEvents.find(
        (e) => e.component === id && e.name === `@resp/${methodCallId}`
      );
      expect(response).toBeDefined();
      expect(response?.data).toEqual({ success: true, data: 6 });

      // Check DOM updated
      const counter = document.querySelector('[data-testid="counter"]');
      expect(counter?.textContent).toBe('6');
    });

    it('should invoke getState method and return component state', async () => {
      const id = uniqueId('stateTest');
      const methodCallId = uniqueId('method-call');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id, {
            props: [
              { name: 'label', value: 'State Test' },
              { name: 'counter', value: 100 },
              { name: 'enabled', value: false },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();
      mock.sentHistory = [];

      // Call getState method
      await mock.simulateEvent({
        component: id,
        name: 'getState',
        data: null,
        id: methodCallId,
      });

      await flushAsync();

      const sentEvents = mock.sentHistory.flat();
      const response = sentEvents.find(
        (e) => e.component === id && e.name === `@resp/${methodCallId}`
      );
      expect(response).toBeDefined();
      expect(response?.data).toEqual({
        success: true,
        data: {
          label: 'State Test',
          counter: 100,
          enabled: false,
        },
      });
    });
  });

  describe('Disabled State', () => {
    it('should respect enabled prop and disable interactions', async () => {
      const id = uniqueId('disabledTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id, {
            props: [
              { name: 'label', value: 'Disabled' },
              { name: 'counter', value: 0 },
              { name: 'enabled', value: false },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      const button = document.querySelector('[data-testid="click-btn"]') as HTMLButtonElement;
      const input = document.querySelector('[data-testid="label-input"]') as HTMLInputElement;

      expect(button.disabled).toBe(true);
      expect(input.disabled).toBe(true);
    });

    it('should enable interactions when enabled prop changes', async () => {
      const id = uniqueId('toggleTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id, {
            props: [
              { name: 'label', value: 'Toggle' },
              { name: 'counter', value: 0 },
              { name: 'enabled', value: false },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      let button = document.querySelector('[data-testid="click-btn"]') as HTMLButtonElement;
      expect(button.disabled).toBe(true);

      // Enable from MATLAB
      await mock.simulateEvent({
        component: id,
        name: '@prop/enabled',
        data: true,
        id: uniqueId('evt'),
      });

      await flushAsync();

      button = document.querySelector('[data-testid="click-btn"]') as HTMLButtonElement;
      expect(button.disabled).toBe(false);
    });
  });

  describe('Instance Styling', () => {
    it('should apply instance styles via @style event', async () => {
      const id = uniqueId('styleTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply style to component
      await mock.simulateEvent({
        component: id,
        name: '@style',
        data: {
          selector: '[data-testid="test-component"]',
          styles: { 'background-color': 'rgb(255, 0, 0)' }
        } as StyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify rule was inserted into adoptedStyleSheets
      // (jsdom doesn't compute styles from adoptedStyleSheets, so we check the rule directly)
      const instanceSheet = document.adoptedStyleSheets.find(
        (s: CSSStyleSheet) => s.cssRules.length > 0 &&
          s.cssRules[0]?.cssText?.includes('background-color')
      );
      expect(instanceSheet).toBeDefined();
      expect(instanceSheet!.cssRules[0].cssText).toContain('rgb(255, 0, 0)');
    });

    it('should clear instance styles via @clearStyle event', async () => {
      const id = uniqueId('clearStyleTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply style
      await mock.simulateEvent({
        component: id,
        name: '@style',
        data: {
          selector: '[data-testid="test-component"]',
          styles: { 'background-color': 'rgb(0, 255, 0)' }
        } as StyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Clear the style
      await mock.simulateEvent({
        component: id,
        name: '@clearStyle',
        data: { selector: '[data-testid="test-component"]' } as ClearStyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Style should be removed (back to default)
      const component = document.querySelector('[data-testid="test-component"]') as HTMLElement;
      const computedStyle = window.getComputedStyle(component);
      expect(computedStyle.backgroundColor).not.toBe('rgb(0, 255, 0)');
    });

    it('should clear all instance styles via @clearStyles event', async () => {
      const id = uniqueId('clearAllTest');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply multiple styles
      await mock.simulateEvent({
        component: id,
        name: '@style',
        data: {
          selector: '[data-testid="test-component"]',
          styles: { 'background-color': 'rgb(0, 0, 255)' }
        } as StyleEventData,
        id: uniqueId('evt'),
      });

      await mock.simulateEvent({
        component: id,
        name: '@style',
        data: {
          selector: '[data-testid="label"]',
          styles: { 'color': 'rgb(255, 255, 0)' }
        } as StyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Clear all styles for this component
      await mock.simulateEvent({
        component: id,
        name: '@clearStyles',
        data: {},
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Both styles should be removed
      const component = document.querySelector('[data-testid="test-component"]') as HTMLElement;
      const label = document.querySelector('[data-testid="label"]') as HTMLElement;
      expect(window.getComputedStyle(component).backgroundColor).not.toBe('rgb(0, 0, 255)');
      expect(window.getComputedStyle(label).color).not.toBe('rgb(255, 255, 0)');
    });
  });

  describe('Global Styling', () => {
    it('should apply global styles via @globalStyle event', async () => {
      const id1 = uniqueId('global1');
      const id2 = uniqueId('global2');

      // Insert two components of the same type
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id1),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id2),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply global style to the component type
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@globalStyle',
        data: {
          type: 'ic.test.TestComponent',
          selector: '[data-testid="test-component"]',
          styles: { 'border': '2px solid rgb(255, 0, 0)' }
        } as GlobalStyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify both components exist
      const components = document.querySelectorAll('[data-testid="test-component"]');
      expect(components.length).toBe(2);

      // Verify rule was inserted with correct selector targeting the type
      const globalSheet = document.adoptedStyleSheets.find(
        (s: CSSStyleSheet) => s.cssRules.length > 0 &&
          s.cssRules[0]?.cssText?.includes('data-ic-type')
      );
      expect(globalSheet).toBeDefined();
      expect(globalSheet!.cssRules[0].cssText).toContain('ic.test.TestComponent');
      expect(globalSheet!.cssRules[0].cssText).toContain('border');
    });

    it('should clear global styles via @clearGlobalStyle event', async () => {
      const id = uniqueId('clearGlobal');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply global style
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@globalStyle',
        data: {
          type: 'ic.test.TestComponent',
          selector: '[data-testid="label"]',
          styles: { 'font-weight': '700' }
        } as GlobalStyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Clear the global style
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@clearGlobalStyle',
        data: {
          type: 'ic.test.TestComponent',
          selector: '[data-testid="label"]'
        } as ClearGlobalStyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      const label = document.querySelector('[data-testid="label"]') as HTMLElement;
      expect(window.getComputedStyle(label).fontWeight).not.toBe('700');
    });

    it('should clear all global styles for a type via @clearGlobalStyles', async () => {
      const id = uniqueId('clearTypeGlobal');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply multiple global styles
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@globalStyle',
        data: {
          type: 'ic.test.TestComponent',
          selector: '[data-testid="test-component"]',
          styles: { 'opacity': '0.5' }
        } as GlobalStyleEventData,
        id: uniqueId('evt'),
      });

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@globalStyle',
        data: {
          type: 'ic.test.TestComponent',
          selector: '[data-testid="label"]',
          styles: { 'text-decoration': 'underline' }
        } as GlobalStyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify rules were added
      const globalSheetBefore = document.adoptedStyleSheets.find(
        (s: CSSStyleSheet) => s.cssRules.length > 0 &&
          s.cssRules[0]?.cssText?.includes('data-ic-type')
      );
      expect(globalSheetBefore!.cssRules.length).toBe(2);

      // Clear all global styles for this type
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@clearGlobalStyles',
        data: { type: 'ic.test.TestComponent' } as ClearGlobalStylesEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify rules were cleared
      const globalSheetAfter = document.adoptedStyleSheets.find(
        (s: CSSStyleSheet) => s.cssRules.length > 0 &&
          s.cssRules[0]?.cssText?.includes('ic.test.TestComponent')
      );
      expect(globalSheetAfter).toBeUndefined();
    });
  });

  describe('Theme', () => {
    it('should apply theme variables via @prop/theme', async () => {
      // Apply theme variables (now via reactive prop)
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@prop/theme',
        data: {
          'test-color': 'rgb(128, 0, 128)',
          'test-spacing': '20px'
        } as ThemeEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Theme variables are now applied as inline styles on the frame element
      const frame = document.getElementById('ic-frame');
      expect(frame).not.toBeNull();
      expect(frame!.style.cssText).toContain('--ic-test-color');
      expect(frame!.style.cssText).toContain('rgb(128, 0, 128)');
      expect(frame!.style.cssText).toContain('--ic-test-spacing');
      expect(frame!.style.cssText).toContain('20px');
    });

    it('should allow components to use theme variables', async () => {
      const id = uniqueId('themeVar');

      // Set theme variable (via reactive prop)
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@prop/theme',
        data: { 'component-bg': 'rgb(100, 150, 200)' } as ThemeEventData,
        id: uniqueId('evt'),
      });

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify theme variable is in frame's inline style
      const frame = document.getElementById('ic-frame');
      expect(frame!.style.cssText).toContain('--ic-component-bg');
      expect(frame!.style.cssText).toContain('rgb(100, 150, 200)');

      // Apply instance style that uses theme variable
      await mock.simulateEvent({
        component: id,
        name: '@style',
        data: {
          selector: '[data-testid="test-component"]',
          styles: { 'background-color': 'var(--ic-component-bg)' }
        } as StyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify instance style references the variable
      const instanceSheet = document.adoptedStyleSheets.find(
        (s: CSSStyleSheet) => s.cssRules.length > 0 &&
          s.cssRules[0]?.cssText?.includes('var(--ic-component-bg)')
      );
      expect(instanceSheet).toBeDefined();
    });
  });

  describe('Style Precedence', () => {
    it('instance styles should override global styles', async () => {
      const id = uniqueId('precedence');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply global style first
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@globalStyle',
        data: {
          type: 'ic.test.TestComponent',
          selector: '[data-testid="test-component"]',
          styles: { 'background-color': 'rgb(255, 0, 0)' }
        } as GlobalStyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Apply instance style (should override due to higher specificity)
      await mock.simulateEvent({
        component: id,
        name: '@style',
        data: {
          selector: '[data-testid="test-component"]',
          styles: { 'background-color': 'rgb(0, 255, 0)' }
        } as StyleEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify both rules exist in the stylesheets
      // (jsdom doesn't compute styles from adoptedStyleSheets)

      // Global style should use data-ic-type selector (lower specificity)
      const globalSheet = document.adoptedStyleSheets.find(
        (s: CSSStyleSheet) => s.cssRules.length > 0 &&
          s.cssRules[0]?.cssText?.includes('data-ic-type')
      );
      expect(globalSheet).toBeDefined();
      expect(globalSheet!.cssRules[0].cssText).toContain('rgb(255, 0, 0)');

      // Instance style should use #id selector (higher specificity)
      const instanceSheet = document.adoptedStyleSheets.find(
        (s: CSSStyleSheet) => s.cssRules.length > 0 &&
          s.cssRules[0]?.cssText?.includes(`#${id}`)
      );
      expect(instanceSheet).toBeDefined();
      expect(instanceSheet!.cssRules[0].cssText).toContain('rgb(0, 255, 0)');
    });
  });

  describe('Logging', () => {
    it('should send @log events to MATLAB when debug is enabled', async () => {
      const id = uniqueId('logTest');

      // Enable debug mode on the frame
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@prop/debug',
        data: true,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Insert a component with triggerLog method
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id, {
            methods: [
              { name: 'echo' },
              { name: 'incrementCounter' },
              { name: 'getState' },
              { name: 'triggerLog' },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();
      mock.sentHistory = []; // Clear history

      // Call triggerLog method which calls logger.error()
      const methodCallId = uniqueId('method-call');
      await mock.simulateEvent({
        component: id,
        name: 'triggerLog',
        data: null,
        id: methodCallId,
      });

      await flushAsync();

      // Should have sent @log event to MATLAB
      const sentEvents = mock.sentHistory.flat();
      const logEvent = sentEvents.find(
        (e) => e.component === 'ic-frame' && e.name === '@log'
      );
      expect(logEvent).toBeDefined();
      expect(logEvent?.data).toMatchObject({
        level: 'error',
        source: 'TestComponent',
        message: 'Test log from Svelte',
      });
    });

    it('should not send @log events when debug is disabled', async () => {
      const id = uniqueId('logDisabled');

      // Debug is false by default, but explicitly set it
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@prop/debug',
        data: false,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Insert component
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestComponentDefinition(id, {
            methods: [
              { name: 'echo' },
              { name: 'incrementCounter' },
              { name: 'getState' },
              { name: 'triggerLog' },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();
      mock.sentHistory = []; // Clear history

      // Call triggerLog
      const methodCallId = uniqueId('method-call');
      await mock.simulateEvent({
        component: id,
        name: 'triggerLog',
        data: null,
        id: methodCallId,
      });

      await flushAsync();

      // Should NOT have sent @log event (debug is off)
      const sentEvents = mock.sentHistory.flat();
      const logEvent = sentEvents.find(
        (e) => e.component === 'ic-frame' && e.name === '@log'
      );
      expect(logEvent).toBeUndefined();
    });
  });

  describe('Static Children', () => {
    it('should create and register static children on insert', async () => {
      const containerId = uniqueId('static-container');
      const childId = `${containerId}-child`;

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestStaticContainerDefinition(containerId),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await waitFor(() => Registry.instance.has(containerId));
      await flushAsync();

      // Both container and static child should be registered
      expect(Registry.instance.has(containerId)).toBe(true);
      expect(Registry.instance.has(childId)).toBe(true);

      // Container should be in the DOM
      const container = document.querySelector('[data-testid="test-static-container"]');
      expect(container).not.toBeNull();

      // Static child should be rendered inside the container
      const childComponent = document.querySelector('[data-testid="test-component"]');
      expect(childComponent).not.toBeNull();
    });

    it('should render static child with initial prop values', async () => {
      const containerId = uniqueId('static-props');

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestStaticContainerDefinition(containerId, {
            props: [
              { name: 'label', value: 'Static Child Label' },
              { name: 'counter', value: 42 },
              { name: 'enabled', value: true },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await waitFor(() => Registry.instance.has(containerId));
      await flushAsync();

      // Check static child rendered with correct props
      const label = document.querySelector('[data-testid="label"]');
      const counter = document.querySelector('[data-testid="counter"]');

      expect(label?.textContent).toBe('Static Child Label');
      expect(counter?.textContent).toBe('42');
    });

    it('should update static child props via @prop events', async () => {
      const containerId = uniqueId('static-update');
      const childId = `${containerId}-child`;

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestStaticContainerDefinition(containerId),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await waitFor(() => Registry.instance.has(childId));
      await flushAsync();

      // Update static child's label prop from MATLAB
      await mock.simulateEvent({
        component: childId,
        name: '@prop/label',
        data: 'Updated Static Label',
        id: uniqueId('evt'),
      });

      await flushAsync();

      const label = document.querySelector('[data-testid="label"]');
      expect(label?.textContent).toBe('Updated Static Label');
    });

    it('should deregister static children when container is removed', async () => {
      const containerId = uniqueId('static-remove');
      const childId = `${containerId}-child`;

      // Insert container with static child
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestStaticContainerDefinition(containerId),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await waitFor(() => Registry.instance.has(childId));
      await flushAsync();

      // Verify both are registered
      expect(Registry.instance.has(containerId)).toBe(true);
      expect(Registry.instance.has(childId)).toBe(true);

      // Remove the container
      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@remove',
        data: { id: containerId } as RemoveEventData,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Both container AND static child should be deregistered
      expect(Registry.instance.has(containerId)).toBe(false);
      expect(Registry.instance.has(childId)).toBe(false);

      // Neither should be in the DOM
      const container = document.querySelector('[data-testid="test-static-container"]');
      const child = document.querySelector('[data-testid="test-component"]');
      expect(container).toBeNull();
      expect(child).toBeNull();
    });

    it('should update parent via frontend-only wiring when static child props change', async () => {
      const containerId = uniqueId('static-wiring');
      const childId = `${containerId}-child`;

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestStaticContainerDefinition(containerId, {
            props: [
              { name: 'label', value: 'Test Label' },
              { name: 'counter', value: 10 },
              { name: 'enabled', value: true },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await waitFor(() => Registry.instance.has(childId));
      await flushAsync();

      // Verify initial childCounter in container mirrors child's counter
      let childCounterDisplay = document.querySelector('[data-testid="child-counter"]');
      expect(childCounterDisplay?.textContent).toBe('Child counter: 10');

      // Update the static child's counter from MATLAB
      await mock.simulateEvent({
        component: childId,
        name: '@prop/counter',
        data: 99,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify the container's childCounter was updated via the $effect
      childCounterDisplay = document.querySelector('[data-testid="child-counter"]');
      expect(childCounterDisplay?.textContent).toBe('Child counter: 99');
    });

    it('should update child via frontend-only wiring when parent props change', async () => {
      const containerId = uniqueId('static-wiring-inverse');
      const childId = `${containerId}-child`;

      await mock.simulateEvent({
        component: 'ic-frame',
        name: '@insert',
        data: {
          component: createTestStaticContainerDefinition(containerId, {
            props: [
              { name: 'label', value: 'Test Label' },
              { name: 'counter', value: 5 },
              { name: 'enabled', value: true },
            ],
          }),
          target: 'default',
        } as InsertEventData,
        id: uniqueId('evt'),
      });

      await waitFor(() => Registry.instance.has(childId));
      await flushAsync();

      // Verify initial child counter
      let childCounter = document.querySelector('[data-testid="counter"]');
      expect(childCounter?.textContent).toBe('5');

      // Update the CONTAINER's childCounter prop from MATLAB
      await mock.simulateEvent({
        component: containerId,
        name: '@prop/childCounter',
        data: 77,
        id: uniqueId('evt'),
      });

      await flushAsync();

      // Verify the child's counter was updated via the inverse $effect
      childCounter = document.querySelector('[data-testid="counter"]');
      expect(childCounter?.textContent).toBe('77');

      // Also verify the container's display updated
      const childCounterDisplay = document.querySelector('[data-testid="child-counter"]');
      expect(childCounterDisplay?.textContent).toBe('Child counter: 77');
    });
  });
});
