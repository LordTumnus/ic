/**
 * FrameComponent - Specialized Component for the root Frame.
 * Handles theme and global style events via FrameStyleManager.
 */

import type { Component as SvelteComponent } from 'svelte';
import type {
  PropDefinition,
  EventDefinition,
  MethodDefinition,
  GlobalStyleEventData,
  ClearGlobalStyleEventData,
  ClearGlobalStylesEventData,
  ThemeEventData
} from '../types';
import Component from './component.svelte';
import FrameStyleManager from './frame-style-manager';

class FrameComponent extends Component {
  constructor(
    propDefinitions: PropDefinition[] = [],
    eventDefinitions: EventDefinition[] = [],
    methodDefinitions: MethodDefinition[] = [],
    targetDefinitions: string[] = ['default'],
    svelteComponent: SvelteComponent<any> | null = null
  ) {
    super('ic-frame', 'ic.Frame', propDefinitions, eventDefinitions, methodDefinitions, targetDefinitions, svelteComponent);

    FrameStyleManager.instance.init(this.id);

    this.subscribe('@theme', (_id, _name, data) => {
      FrameStyleManager.instance.setTheme(data as ThemeEventData);
    });
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
