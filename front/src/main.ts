import Bridge from './lib/core/bridge';
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

  // Initialize the Bridge with the MATLAB HTML element
  bridge.setup(matlabHtml);

  // Wire incoming events to the Registry (Phase 3)
  // For now, just log events until Registry is implemented
  bridge.setDispatcher((event) => {
    console.log('[main] Received event from MATLAB:', event);
    // TODO: Registry.dispatch(event) - will be added in Phase 3
  });
};
