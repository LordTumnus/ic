<!--
  TestComponent.svelte - Integration test component.

  This component mirrors MATLAB's ic.test.TestComponent and provides
  all reactive features needed for integration testing:
  - Props: label, counter, enabled (bidirectional sync with MATLAB)
  - Events: clicked, valueChanged (Svelte → MATLAB)
  - Methods: echo, incrementCounter (MATLAB → Svelte with response)
-->
<script lang="ts">
  import type { Resolution } from '$lib/types';

  let {
    // Reactive props (synced with MATLAB)
    label = $bindable(''),
    counter = $bindable(0),
    enabled = $bindable(true),

    // Event handlers (call these to send events to MATLAB)
    clicked,
    valueChanged,

    // Method handlers (MATLAB calls these, we provide implementations)
    echo = $bindable((value: unknown): Resolution => ({ success: true, data: value })),
    incrementCounter = $bindable((): Resolution => ({ success: true, data: null })),
    getState = $bindable((): Resolution => ({ success: true, data: null }))
  }: {
    label?: string;
    counter?: number;
    enabled?: boolean;
    clicked?: (data?: unknown) => void;
    valueChanged?: (data?: unknown) => void;
    echo?: (value: unknown) => Resolution;
    incrementCounter?: () => Resolution;
    getState?: () => Resolution;
  } = $props();

  // Set up method implementations
  // These override the default implementations provided by the Component class
  $effect(() => {
    echo = (value: unknown): Resolution => {
      return { success: true, data: value };
    };

    incrementCounter = (): Resolution => {
      counter += 1;
      return { success: true, data: counter };
    };

    getState = (): Resolution => {
      return {
        success: true,
        data: { label, counter, enabled }
      };
    };
  });

  function handleClick() {
    clicked?.({ timestamp: Date.now() });
  }

  function handleInputChange(event: Event) {
    const target = event.target as HTMLInputElement;
    label = target.value;
    valueChanged?.({ field: 'label', value: label });
  }

  function handleCounterChange(delta: number) {
    counter += delta;
    valueChanged?.({ field: 'counter', value: counter });
  }
</script>

<div class="test-component" class:disabled={!enabled} data-testid="test-component">
  <div class="header">
    <span class="label" data-testid="label">{label}</span>
    <span class="counter" data-testid="counter">{counter}</span>
  </div>

  <div class="controls">
    <input
      type="text"
      value={label}
      oninput={handleInputChange}
      disabled={!enabled}
      data-testid="label-input"
    />

    <div class="counter-controls">
      <button
        onclick={() => handleCounterChange(-1)}
        disabled={!enabled}
        data-testid="decrement-btn"
      >
        -
      </button>
      <button
        onclick={() => handleCounterChange(1)}
        disabled={!enabled}
        data-testid="increment-btn"
      >
        +
      </button>
    </div>

    <button
      onclick={handleClick}
      disabled={!enabled}
      data-testid="click-btn"
    >
      Click Me
    </button>
  </div>
</div>

<style>
  .test-component {
    padding: 1rem;
    border: 2px solid #ccc;
    border-radius: 8px;
    font-family: system-ui, sans-serif;
  }

  .test-component.disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .header {
    display: flex;
    justify-content: space-between;
    margin-bottom: 1rem;
    font-size: 1.2rem;
  }

  .label {
    font-weight: bold;
  }

  .counter {
    background: #e0e0e0;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-family: monospace;
  }

  .controls {
    display: flex;
    gap: 0.5rem;
    align-items: center;
    flex-wrap: wrap;
  }

  input {
    flex: 1;
    min-width: 100px;
    padding: 0.5rem;
    border: 1px solid #ccc;
    border-radius: 4px;
  }

  .counter-controls {
    display: flex;
    gap: 0.25rem;
  }

  button {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    background: #007bff;
    color: white;
    cursor: pointer;
  }

  button:hover:not(:disabled) {
    background: #0056b3;
  }

  button:disabled {
    background: #ccc;
    cursor: not-allowed;
  }
</style>
