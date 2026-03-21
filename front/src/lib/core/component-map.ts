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

  // Editor components
  'ic.CodeEditor': modules['../components/editor/codeEditor/CodeEditor.svelte'],
  'ic.RichEditor': modules['../components/editor/RichEditor/RichEditor.svelte'],
  'ic.NodeEditor': modules['../components/editor/nodeEditor/NodeEditor.svelte'],
  'ic.node.Port': modules['../components/editor/nodeEditor/PortProxy.svelte'],
  'ic.node.Transform': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.BasicGroup': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.CollapsibleGroup': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Input': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Output': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Constant': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Clock': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Signal': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Random': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Display': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Meter': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Logger': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Gain': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Delay': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Switch': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Mux': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Demux': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Accumulator': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Note': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Function': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Process': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Decision': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Terminator': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Database': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Cloud': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Document': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Queue': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Actor': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.IconBox': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.ClassNode': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.IcNode': modules['../components/editor/nodeEditor/NodeProxy.svelte'],
  'ic.node.Edge': modules['../components/editor/nodeEditor/EdgeProxy.svelte'],
  'ic.node.StaticEdge': modules['../components/editor/nodeEditor/EdgeProxy.svelte'],
  'ic.node.FlowEdge': modules['../components/editor/nodeEditor/EdgeProxy.svelte'],
  'ic.node.SignalEdge': modules['../components/editor/nodeEditor/EdgeProxy.svelte'],

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
  'ic.TabContainer': modules['../components/layout/tabContainer/TabContainer.svelte'],
  'ic.tab.Tab': modules['../components/layout/tabContainer/Tab.svelte'],
  'ic.tab.TabPanel': modules['../components/layout/tabContainer/TabPanel.svelte'],
  'ic.TileLayout': modules['../components/layout/tileLayout/TileLayout.svelte'],

  // Panel components
  'ic.Panel': modules['../components/panel/panel/Panel.svelte'],

  // Renderer components
  'ic.PDFViewer': modules['../components/renderer/pdfViewer/PDFViewer.svelte'],
  'ic.Markdown': modules['../components/renderer/markdown/Markdown.svelte'],
  'ic.Mermaid': modules['../components/renderer/mermaid/Mermaid.svelte'],
  'ic.Typst': modules['../components/renderer/typst/Typst.svelte'],
  'ic.Latex': modules['../components/renderer/latex/Latex.svelte'],

  // Table components
  'ic.Table': modules['../components/table/table/Table.svelte'],
  'ic.VirtualTable': modules['../components/table/virtualTable/VirtualTable.svelte'],

  // Tree components
  'ic.Tree': modules['../components/tree/tree/Tree.svelte'],
  'ic.VirtualTree': modules['../components/tree/virtualTree/VirtualTree.svelte'],
  'ic.FilterTree': modules['../components/tree/filterTree/FilterTree.svelte'],
  'ic.VirtualFilterTree': modules['../components/tree/virtualFilterTree/VirtualFilterTree.svelte'],
  'ic.TreeTable': modules['../components/tree/treeTable/TreeTable.svelte'],
  'ic.VirtualTreeTable': modules['../components/tree/virtualTreeTable/VirtualTreeTable.svelte'],

  // Overlay components
  'ic.Toast': modules['../components/overlay/toast/Toast.svelte'],
  'ic.Dialog': modules['../components/overlay/dialog/Dialog.svelte'],
  'ic.Drawer': modules['../components/overlay/drawer/Drawer.svelte'],
  'ic.Popover': modules['../components/overlay/popover/Popover.svelte'],
  'ic.popover.Panel': modules['../components/overlay/popover/PopoverPanel.svelte'],

  // Internal components
  'ic.internal.DeveloperTools': modules['../components/internal/developerTools/DeveloperTools.svelte'],
  'ic.internal.WorkerTest': modules['../components/internal/workerTest/WorkerTest.svelte'],
  'ic.internal.DragDropTest': modules['../components/internal/dragDropTest/DragDropTest.svelte'],

  // Tweakpane components
  'ic.TweakPane': modules['../components/tweakpane/TweakPane.svelte'],
  'ic.tp.Slider': modules['../components/tweakpane/blades/TpSlider.svelte'],
  'ic.tp.Checkbox': modules['../components/tweakpane/blades/TpCheckbox.svelte'],
  'ic.tp.Text': modules['../components/tweakpane/blades/TpText.svelte'],
  'ic.tp.Color': modules['../components/tweakpane/blades/TpColor.svelte'],
  'ic.tp.Point': modules['../components/tweakpane/blades/TpPoint.svelte'],
  'ic.tp.List': modules['../components/tweakpane/blades/TpList.svelte'],
  'ic.tp.Button': modules['../components/tweakpane/blades/TpButton.svelte'],
  'ic.tp.Separator': modules['../components/tweakpane/blades/TpSeparator.svelte'],
  'ic.tp.Monitor': modules['../components/tweakpane/blades/TpMonitor.svelte'],
  'ic.tp.Folder': modules['../components/tweakpane/blades/TpFolder.svelte'],
  'ic.tp.TabGroup': modules['../components/tweakpane/blades/TpTabGroup.svelte'],
  'ic.tp.TabPage': modules['../components/tweakpane/blades/TpTabPage.svelte'],
  'ic.tp.IntervalSlider': modules['../components/tweakpane/blades/TpIntervalSlider.svelte'],
  'ic.tp.FpsGraph': modules['../components/tweakpane/blades/TpFpsGraph.svelte'],
  'ic.tp.RadioGrid': modules['../components/tweakpane/blades/TpRadioGrid.svelte'],
  'ic.tp.ButtonGrid': modules['../components/tweakpane/blades/TpButtonGrid.svelte'],
  'ic.tp.CubicBezier': modules['../components/tweakpane/blades/TpCubicBezier.svelte'],
  'ic.tp.Ring': modules['../components/tweakpane/blades/TpRing.svelte'],
  'ic.tp.Wheel': modules['../components/tweakpane/blades/TpWheel.svelte'],
  'ic.tp.Rotation': modules['../components/tweakpane/blades/TpRotation.svelte'],
  'ic.tp.Textarea': modules['../components/tweakpane/blades/TpTextarea.svelte'],
  'ic.tp.Image': modules['../components/tweakpane/blades/TpImage.svelte'],
};

export default componentMap;
