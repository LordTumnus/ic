import Bridge from './lib/core/bridge';
import Registry from './lib/core/registry';
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

  // TODO (Phase 5): Create and register Frame here BEFORE wiring dispatcher
  // const frame = new Frame();
  // registry.register(frame);

  // Wire incoming events from Bridge to Registry for dispatch
  bridge.setDispatcher((event) => registry.dispatch(event));

  // Initialize the Bridge (starts listening for MATLAB events)
  bridge.setup(matlabHtml);
};
