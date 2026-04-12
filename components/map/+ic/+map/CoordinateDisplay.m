classdef CoordinateDisplay < ic.map.Control
    % displays the cursor's geographic coordinates on the map.
    % Shows lat/lng values that update as the mouse moves over the map.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % number of decimal places for lat/lng display
        Precision (1,1) double = 5

        % text prefix before coordinates
        Prefix (1,1) string = ""

        % separator between lat and lng values
        Separator (1,1) string = " | "

        % text shown when the cursor is off the map
        EmptyText (1,1) string = "---"
    end

    methods
        function this = CoordinateDisplay(props)
            arguments
                props.?ic.map.CoordinateDisplay
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            props.Position = "bottomleft";
            this@ic.map.Control(props);
        end
    end
end
