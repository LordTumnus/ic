import Bridge from './lib/core/bridge';
import Registry from './lib/core/registry';
import Component from './lib/core/component.svelte';
import Frame from './lib/components/core/frame/Frame.svelte';
import type { MatlabHTML } from './lib/types';

declare global {
  interface Window {
    setup: (matlabHtml: MatlabHTML) => void;
  }
}

/**
 * Entry point called by MATLAB when the HTML component is ready.
 *
 * @param matlabHtml - The HTML element MATLAB uses for bidirectional communication
 */
window.setup = (matlabHtml: MatlabHTML) => {
  const bridge = Bridge.instance;
  const registry = Registry.instance;

  // Create, register and mount Frame into document body
  const frame = new Component(
    '@ic.frame', 'ic.Frame', [], [], [], ['default'], Frame
  );
  registry.register(frame);
  frame.mount(document.body);

  // Wire incoming events from Bridge to Registry for dispatch
  bridge.setDispatcher((event) => registry.dispatch(event));

  // Initialize the Bridge (starts listening for MATLAB events)
  bridge.setup(matlabHtml);
};
