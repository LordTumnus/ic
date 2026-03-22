classdef ButtonGrid < ic.tp.Blade
    % > BUTTONGRID Grid of buttons (plugin-essentials).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS button labels
        Items (1,:) string = string.empty
        % > COLUMNS number of grid columns
        Columns (1,1) double = 2
    end

    events (Description = "Reactive")
        % > CLICKED fires when a button is clicked (value = button label)
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
