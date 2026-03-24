classdef ButtonGrid < ic.tp.Blade
    % grid of buttons blade for TweakPane.
    % Uses [@tweakpane/plugin-essentials](https://github.com/tweakpane/plugin-essentials)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % button labels
        Items (1,:) string = string.empty

        % number of grid columns
        Columns (1,1) double = 2
    end

    events (Description = "Reactive")
        % fires when any button in the grid is clicked
        % {payload}
        % value | char: label of the clicked button
        % {/payload}
        Clicked
    end

    methods
        function this = ButtonGrid(props)
            arguments
                props.?ic.tp.ButtonGrid
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
