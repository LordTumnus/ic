classdef ColorPicker < ic.core.Component
    % > COLORPICKER Color selection control with hue/alpha sliders.
    %
    %   Displays a colored swatch that opens a popup editor with a hue
    %   slider, an alpha slider, and optional preset color swatches.
    %
    %   Example:
    %       cp = ic.ColorPicker();
    %       cp.Value = "#ff6600";
    %       cp.Format = "hex";
    %       cp.ShowLabel = true;
    %       cp.Presets = ["#ff0000", "#00ff00", "#0000ff", "#ffff00"];

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current color value as a string
        Value string = "#3b82f6"
        % > SHOWALPHA whether to show the alpha slider and include alpha in the value
        ShowAlpha logical = false
        % > FORMAT display format for the color value
        Format string {mustBeMember(Format, ...
            ["hex", "rgb", "hsl"])} = "hex"
        % > SHOWLABEL whether to display the color value text next to the swatch
        ShowLabel logical = false
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > SIZE size of the swatch trigger
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > PRESETS array of preset color strings
        Presets string = string.empty
        % > POPUPPOSITION where the popup opens relative to the swatch
        PopupPosition string {mustBeMember(PopupPosition, ...
            ["bottom", "top", "left", "right", "best"])} = "best"
    end

    events (Description = "Reactive")
        % > VALUECHANGING fires while the color value is being changed
        ValueChanging
        % > OPENED fires when the color editor popup opens
        Opened
        % > CLOSED fires when the color editor popup closes
        Closed
    end

    methods
        function this = ColorPicker(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the swatch trigger
            out = this.publish("focus", []);
        end
    end
end
