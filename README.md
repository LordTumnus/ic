# IC Framework

Build rich, reactive apps in MATLAB with modern web components.

IC lets you create interactive components inside figures that are directly controlled from MATLAB.

```matlab
fig = uifigure();
layout = uigridlayout(fig, "RowHeight", {'1x'}, "ColumnWidth", {'1x'});

frame = ic.Frame("Parent", layout);

slider = ic.Slider("Min", 0, "Max", 100, "Value", 50);
label  = ic.Label("Text", "Value: 50");

frame.addChild(slider);
frame.addChild(label);

addlistener(slider, 'ValueChanged', @(~, e) ...
    set(label, "Text", "Value: " + e.Data.value));
```

## Documentation

Full docs, interactive playgrounds, and API reference at **[ic-matlab.netlify.app](https://ic-matlab.netlify.app/)**.

## Getting started

1. Download IC from the [MATLAB File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/) or clone this repo
2. Add the framework to your MATLAB path
3. Create a uifigure and an `ic.Frame`

## Requirements

- MATLAB R2024b or later

## License

See [LICENSE](LICENSE) for details.
