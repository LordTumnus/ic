import './lib/utils/polyfills';
import '@fontsource/roboto-mono/400.css';
import '@fontsource/roboto-mono/500.css';
import '@fontsource/roboto-mono/600.css';

import Bridge from './lib/core/bridge';
import Registry from './lib/core/registry';
import FrameComponent from './lib/core/frame-component.svelte';
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

  // Attach listener first — captures any events already buffered by uihtml
  bridge.setup(matlabHtml);

  // Create, register and mount Frame into document body
  const frame = new FrameComponent(Frame);
  registry.register(frame);
  frame.mount(document.body);

  // Wire dispatchers and drain any events that arrived during mount
  bridge.setDispatcher(
    (event) => registry.dispatch(event),
    (event) => registry.dispatchSync(event)
  );

  // Signal MATLAB that the frontend is fully initialized and ready
  // to receive events. View queues all events until this handshake
  // completes, ensuring sendEventToHTMLSource is only called after
  // the page is loaded and the event listener is attached.
  matlabHtml.sendEventToMATLAB('ready', '');
};
