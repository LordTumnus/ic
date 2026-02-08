/**
 * Component Map - Maps MATLAB types to Svelte component loaders.
 *
 * This file is the single source of truth for which MATLAB classes
 * correspond to which Svelte components.
 *
 * When adding a new component:
 * 1. Create the Svelte component file
 * 2. Add its mapping here using the glob import
 *
 * Uses import.meta.glob for Vite-compatible dynamic imports.
 */

// Vite glob import - eagerly discovers all Svelte components at build time
const modules = import.meta.glob('../components/**/*.svelte');

/**
 * Maps MATLAB type names to their module loader functions.
 * The loader functions return a Promise that resolves to the component module.
 */
const componentMap: Record<string, () => Promise<unknown>> = {
  // Test components (for integration testing)
  'ic.test.TestComponent': modules['../components/test/TestComponent.svelte'],
  'ic.test.TestStaticContainer': modules['../components/test/TestStaticContainer.svelte'],

  // Display components
  'ic.Icon': modules['../components/display/icon/Icon.svelte'],
  'ic.Label': modules['../components/display/label/Label.svelte'],
  'ic.ProgressBar': modules['../components/display/progressBar/ProgressBar.svelte'],
  'ic.CircularProgressBar': modules['../components/display/circularProgressBar/CircularProgressBar.svelte'],
  'ic.Spinner': modules['../components/display/spinner/Spinner.svelte'],

  // Form components
  'ic.Button': modules['../components/form/button/Button.svelte'],
  'ic.ToggleButton': modules['../components/form/toggleButton/ToggleButton.svelte'],
  'ic.Slider': modules['../components/form/slider/Slider.svelte'],
  'ic.RangeSlider': modules['../components/form/rangeSlider/RangeSlider.svelte'],
  'ic.Switch': modules['../components/form/switch/Switch.svelte'],
  'ic.SegmentedButton': modules['../components/form/segmentedButton/SegmentedButton.svelte'],
  'ic.InputText': modules['../components/form/inputText/InputText.svelte'],
  'ic.TextArea': modules['../components/form/textarea/TextArea.svelte'],
  'ic.Checkbox': modules['../components/form/checkbox/Checkbox.svelte'],

  // Layout components
  'ic.FlexContainer': modules['../components/layout/flexContainer/FlexContainer.svelte'],
  'ic.GridContainer': modules['../components/layout/gridContainer/GridContainer.svelte'],

  // Panel components
  'ic.Panel': modules['../components/panel/panel/Panel.svelte'],
  'ic.Splitter': modules['../components/panel/splitter/Splitter.svelte'],
};

export default componentMap;
