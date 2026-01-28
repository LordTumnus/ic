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
import Component from '$lib/core/component.svelte';
import Frame from '$lib/components/core/frame/Frame.svelte';
import MockMatlabHTML from '../mocks/matlab-html';
import type { ComponentDefinition, InsertEventData, RemoveEventData } from '$lib/types';

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
 * Helper to set up the bridge with a mock MATLAB element.
 * Returns the mock for test assertions.
 */
function setupBridge(): MockMatlabHTML {
  const mock = new MockMatlabHTML();
  const bridge = Bridge.instance;
  const registry = Registry.instance;

  // Create and register the Frame (root component)
  const frame = new Component(
    'ic-frame', 'ic.Frame', [], [], [], ['default'], Frame
  );
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
      mock.sentHistory = []; // Clear history from setup

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
      mock.sentHistory = []; // Clear history

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
});
