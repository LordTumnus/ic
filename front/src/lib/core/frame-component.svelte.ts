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
import type { LogLevel } from './logger';
import Component from './component.svelte';
import FrameStyleManager from './frame-style-manager';
import logger from './logger';

// Default theme values matching MATLAB's ic.style.Theme defaults
// Slate-based engineering palette with blue accents
// Color properties are [light, dark] arrays; non-color properties are single values
const defaultTheme = {
  background: ['#f8fafc', '#0f172a'],
  foreground: ['#0f172a', '#f1f5f9'],
  primary: ['#2563eb', '#3b82f6'],
  'primary-foreground': ['#ffffff', '#ffffff'],
  secondary: ['#e2e8f0', '#1e293b'],
  'secondary-foreground': ['#0f172a', '#f1f5f9'],
  muted: ['#f1f5f9', '#1e293b'],
  'muted-foreground': ['#64748b', '#94a3b8'],
  accent: ['#dbeafe', '#1e3a5f'],
  'accent-foreground': ['#1e40af', '#93c5fd'],
  destructive: ['#dc2626', '#ef4444'],
  'destructive-foreground': ['#ffffff', '#ffffff'],
  border: ['#cbd5e1', '#334155'],
  input: ['#cbd5e1', '#475569'],
  ring: ['#2563eb', '#3b82f6'],
  radius: '0.375rem'
};

class FrameComponent extends Component {
  constructor(svelteComponent: SvelteComponent<any>) {
    super(
      'ic-frame',
      'ic.Frame',
      [
        { name: 'theme', value: defaultTheme },
        { name: 'colorScheme', value: 'light' },
        { name: 'debug', value: false },
        { name: 'logLevel', value: 'debug' },
        { name: 'fillFirstChild', value: false }
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

    // Logger integration
    this.subscribe('@prop/debug', (_id, _name, data) => {
      const enabled = data as boolean;
      if (enabled) {
        logger.enable((entry) => this.publish('@log', entry));
        logger.info('Logger', 'Debug mode enabled');
      } else {
        logger.info('Logger', 'Debug mode disabled');
        logger.disable();
      }
    });

    this.subscribe('@prop/logLevel', (_id, _name, data) => {
      logger.configure({ minLevel: data as LogLevel });
    });
  }
}

export default FrameComponent;
