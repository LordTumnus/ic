classdef RadioGrid < ic.tp.Blade
    % grid of radio buttons blade for TweakPane.
    % uses [@tweakpane/plugin-essentials](https://github.com/tweakpane/plugin-essentials).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % currently selected item
        Value (1,1) string = ""

        % list of options displayed as radio buttons
        Items (1,:) string = string.empty

        % number of grid columns
        Columns (1,1) double = 2
    end

    events (Description = "Reactive")
        % fires when the selection changes
        % {payload}
        % value | char: selected item
        % {/payload}
        ValueChanged
    end

    methods
        function this = RadioGrid(props)
            arguments
                props.?ic.tp.RadioGrid
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
