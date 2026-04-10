classdef Polyline < ic.map.Path
    % line path on a Leaflet map defined by an array of [lat, long] positions.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % ordered positions as an Nx2 matrix of [lat, long] rows
        Positions (:,2) double = zeros(0,2)
    end

    methods
        function this = Polyline(props)
            arguments
                props.?ic.map.Polyline
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Path(props);
        end
    end
end
