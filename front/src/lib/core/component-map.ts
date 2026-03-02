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
  'ic.Image': modules['../components/display/image/Image.svelte'],
  'ic.Tree': modules['../components/display/tree/Tree.svelte'],
  'ic.VirtualTree': modules['../components/display/virtualTree/VirtualTree.svelte'],
  'ic.FilterTree': modules['../components/display/filterTree/FilterTree.svelte'],
  'ic.VirtualFilterTree': modules['../components/display/virtualFilterTree/VirtualFilterTree.svelte'],
  'ic.PDFViewer': modules['../components/display/pdfViewer/PDFViewer.svelte'],
  'ic.Table': modules['../components/display/table/Table.svelte'],
  'ic.VirtualTable': modules['../components/display/virtualTable/VirtualTable.svelte'],
  'ic.TreeTable': modules['../components/display/treeTable/TreeTable.svelte'],
  'ic.VirtualTreeTable': modules['../components/display/virtualTreeTable/VirtualTreeTable.svelte'],

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
  'ic.Password': modules['../components/form/password/Password.svelte'],
  'ic.Knob': modules['../components/form/knob/Knob.svelte'],
  'ic.RadioButton': modules['../components/form/radioButton/RadioButton.svelte'],
  'ic.ColorPicker': modules['../components/form/colorPicker/ColorPicker.svelte'],
  'ic.SplitButton': modules['../components/form/splitButton/SplitButton.svelte'],
  'ic.Select': modules['../components/form/select/Select.svelte'],
  'ic.MultiSelect': modules['../components/form/multiSelect/MultiSelect.svelte'],
  'ic.TreeSelect': modules['../components/form/treeSelect/TreeSelect.svelte'],
  'ic.SearchBar': modules['../components/form/searchBar/SearchBar.svelte'],

  // Layout components
  'ic.FlexContainer': modules['../components/layout/flexContainer/FlexContainer.svelte'],
  'ic.GridContainer': modules['../components/layout/gridContainer/GridContainer.svelte'],
  'ic.Splitter': modules['../components/layout/splitter/Splitter.svelte'],
  'ic.SplitterPane': modules['../components/layout/splitter/SplitterPane.svelte'],

  // Panel components
  'ic.Panel': modules['../components/panel/panel/Panel.svelte'],

  // Internal components
  'ic.internal.DeveloperTools': modules['../components/internal/developerTools/DeveloperTools.svelte'],

};

export default componentMap;
