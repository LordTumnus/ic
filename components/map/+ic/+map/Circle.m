classdef Circle < ic.map.Path
    % circle on a Leaflet map with a radius in meters.
    % The circle scales with the map projection (grows/shrinks on zoom).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % center position as [lat, long]
        Center (1,2) double = [0, 0]

        % radius in meters
        Radius (1,1) double = 100
    end

    methods
        function this = Circle(props)
            arguments
                props.?ic.map.Circle
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Path(props);
            if ~any(strcmp(fieldnames(props), 'Fill'))
                this.Fill = true;
            end
        end
    end
end
