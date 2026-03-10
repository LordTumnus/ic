classdef RadioGrid < ic.tp.Blade
    % > RADIOGRID Grid of radio buttons (plugin-essentials).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE currently selected item
        Value (1,1) string = ""
        % > ITEMS list of options
        Items (1,:) string = string.empty
        % > COLUMNS number of grid columns
        Columns (1,1) double = 2
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the selection changes
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
