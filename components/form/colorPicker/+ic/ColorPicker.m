classdef ColorPicker < ic.core.Component
    % color selection control.
    % Displays a colored swatch that opens a popup editor with a hue
    % slider, an alpha slider, and optional preset color swatches.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current color value as a string
        Value string = "#3b82f6"

        % whether to show the alpha slider and include alpha in the #ic.ColorPicker.Value
        ShowAlpha logical = false

        % display format for the color value
        Format string {mustBeMember(Format, ...
            ["hex", "rgb", "hsl"])} = "hex"

        % whether to display the color value in text form next to the swatch
        ShowLabel logical = false

        % whether the control is disabled and cannot be interacted with
        Disabled logical = false

        % size of the swatch trigger, relative to its font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % list of preset colors to show as additional swatches in the popup editor. Each color should be a valid CSS color string
        Presets string = string.empty

        % position where the popup opens relative to the swatch. If "best", the position will be automatically chosen to fit within the viewport.
        PopupPosition string {mustBeMember(PopupPosition, ...
            ["bottom", "top", "left", "right", "best"])} = "best"
    end

    events (Description = "Reactive")
        % triggered while the color value is being changed (this differs from #ic.ColorPicker.Value in that it is not debounced, so it fires on every change as the user drags the sliders in the editor)
        % {payload}
        % value | char: current color string in the active format
        % {/payload}
        ValueChanging

        % fires when the color editor popup opens
        Opened

        % fires when the color editor popup closes
        Closed
    end

    methods
        function this = ColorPicker(props)
            arguments
                props.?ic.ColorPicker
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the swatch trigger
            out = this.publish("focus", []);
        end
    end
end
