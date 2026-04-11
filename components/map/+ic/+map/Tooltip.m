classdef Tooltip < ic.map.Layer
    % standalone tooltip at a fixed geographic position on a Leaflet map.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % geographic position as [lat, lng]
        Position (1,2) double = [0, 0]

        % HTML content displayed inside the tooltip
        Content (1,1) string = ""

        % whether the tooltip is always visible (true) or only on hover (false)
        Permanent (1,1) logical = true

        % tooltip direction relative to the anchor point
        Direction (1,1) string {mustBeMember(Direction, ...
            ["auto", "top", "bottom", "left", "right", "center"])} = "auto"

        % tooltip opacity (0 to 1)
        Opacity (1,1) double = 0.9
    end

    methods
        function this = Tooltip(props)
            arguments
                props.?ic.map.Tooltip
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end
    end
end
