# IC Framework

<a href="https://uk.mathworks.com/matlabcentral/fileexchange/183586-ic-figure-components"><img src="https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg" width="144.5"></a>

Interactive components for MATLAB figures.

<p align="center">
  <img src="media/hero.gif" alt="IC Framework demo" width="100%">
</p>

## Components

| | |
|---|---|
| **Form** | Button, ToggleButton, Slider, RangeSlider, Knob, Switch, Checkbox, RadioButton, SegmentedButton, Select, MultiSelect, TreeSelect, ColorPicker, SplitButton, InputText, TextArea, Password, SearchBar |
| **Display** | Label, Image, ProgressBar, CircularProgressBar, Spinner |
| **Data** | Table, VirtualTable, Tree, VirtualTree, FilterTree, VirtualFilterTree, TreeTable, VirtualTreeTable |
| **Layout** | FlexContainer, GridContainer, Splitter, TabContainer, TileLayout, Accordion, Panel |
| **Renderers** | Latex, Markdown, Typst, Mermaid, PDFViewer |
| **Editors** | CodeEditor, RichEditor, NodeEditor |
| **Maps** | Leaflet-based maps with markers, polylines, polygons, GeoJSON, WMS, heatmaps |
| **Overlays** | Dialog, Drawer, Toast, Popover |
| **Tweakpane** | Parameter tuning panel with slider, color, point, bezier, rotation blades and more |

## Quick start

Create a figure, add a grid layout, and insert an `ic.Frame` -- that's where your components live.

```matlab
fig = uifigure();
gl  = uigridlayout(fig, "RowHeight", {'1x'}, "ColumnWidth", {'1x'});
frame = ic.Frame("Parent", gl);
```

## Examples

### LaTeX Editor

<!-- TODO: gif -->

Full LaTeX editor with live preview, PDF export, and figure capture.

```matlab
ic.examples.LatexEditor
```

### Surface Explorer

<!-- TODO: gif -->

3D surface plot with TweakPane controls.

```matlab
ic.examples.SurfaceExplorer
```

## Getting started

1. Download from the [File Exchange](https://uk.mathworks.com/matlabcentral/fileexchange/183586-ic-figure-components) or clone this repo
2. Add the framework to your MATLAB path
3. Run one of the examples above

## Documentation

[ic-matlab.netlify.app](https://ic-matlab.netlify.app/)

## Requirements

MATLAB R2024b or later.

## License

See [LICENSE](LICENSE).
