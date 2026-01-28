/**
 * FrameComponent - Specialized Component for the root Frame.
 *
 * Theme is handled as a regular reactive prop (applied via inline style in Frame.svelte).
 * Global styles are handled via FrameStyleManager (requires Constructable Stylesheets).
 */

import type { Component as SvelteComponent } from 'svelte';
import type {
  GlobalStyleEventData,
  ClearGlobalStyleEventData,
  ClearGlobalStylesEventData
} from '../types';
import Component from './component.svelte';
import FrameStyleManager from './frame-style-manager';

class FrameComponent extends Component {
  constructor(svelteComponent: SvelteComponent<any>) {
    super(
      'ic-frame',
      'ic.Frame',
      [{ name: 'theme', value: {} }],
      [],
      [],
      ['default'],
      svelteComponent
    );

    FrameStyleManager.instance.init(this.id);

    this.subscribe('@globalStyle', (_id, _name, data) => {
      const { type, selector, styles } = data as GlobalStyleEventData;
      FrameStyleManager.instance.setGlobalStyle(type, selector, styles);
    });
    this.subscribe('@clearGlobalStyle', (_id, _name, data) => {
      const { type, selector } = data as ClearGlobalStyleEventData;
      FrameStyleManager.instance.clearGlobalStyle(type, selector);
    });
    this.subscribe('@clearGlobalStyles', (_id, _name, data) => {
      const { type } = data as ClearGlobalStylesEventData;
      FrameStyleManager.instance.clearGlobalStyles(type);
    });
    this.subscribe('@clearAllGlobalStyles', () => {
      FrameStyleManager.instance.clearAllGlobalStyles();
    });
  }
}

export default FrameComponent;
