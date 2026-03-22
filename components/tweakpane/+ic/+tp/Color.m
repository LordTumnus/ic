classdef Color < ic.tp.Blade
    % > COLOR Color picker blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE hex color string (e.g. "#3b82f6")
        Value (1,1) string = "#3b82f6"
        % > SHOWALPHA whether to show the alpha channel
        ShowAlpha (1,1) logical = false
    end

    events (Description = "Reactive")
        % > VALUECHANGING fires during color picking
        ValueChanging
        % > VALUECHANGED fires when color is committed
        ValueChanged
    end

    methods
        function this = Color(props)
            arguments
                props.?ic.tp.Color
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
