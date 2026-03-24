classdef Color < ic.tp.Blade
    % color picker blade for TweakPane

    properties (SetObservable, AbortSet, Description = "Reactive")
        % hex color string
        Value (1,1) string = "#3b82f6"

        % whether to show the alpha channel slider
        ShowAlpha (1,1) logical = false
    end

    events (Description = "Reactive")
        % fires continuously while the color picker is open
        % {payload}
        % value | char: current hex color string
        % {/payload}
        ValueChanging

        % fires when the color is committed (picker closed)
        % {payload}
        % value | char: committed hex color string
        % {/payload}
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
