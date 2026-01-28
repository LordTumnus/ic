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

// Default theme values matching MATLAB's ic.style.Theme defaults
// Color properties are [light, dark] arrays; non-color properties are single values
const defaultTheme = {
  background: ['#ffffff', '#09090b'],
  foreground: ['#09090b', '#fafafa'],
  primary: ['#18181b', '#fafafa'],
  'primary-foreground': ['#fafafa', '#18181b'],
  secondary: ['#f4f4f5', '#27272a'],
  'secondary-foreground': ['#18181b', '#fafafa'],
  muted: ['#f4f4f5', '#27272a'],
  'muted-foreground': ['#71717a', '#a1a1aa'],
  accent: ['#f4f4f5', '#27272a'],
  'accent-foreground': ['#18181b', '#fafafa'],
  destructive: ['#ef4444', '#7f1d1d'],
  'destructive-foreground': ['#fafafa', '#fef2f2'],
  border: ['#e4e4e7', '#27272a'],
  input: ['#e4e4e7', '#27272a'],
  ring: ['#18181b', '#d4d4d8'],
  radius: '0.5rem'
};

class FrameComponent extends Component {
  constructor(svelteComponent: SvelteComponent<any>) {
    super(
      'ic-frame',
      'ic.Frame',
      [
        { name: 'theme', value: defaultTheme },
        { name: 'colorScheme', value: 'light' }
      ],
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
