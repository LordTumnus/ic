classdef Polygon < ic.map.Path
    % closed polygon on a Leaflet map defined by an array of [lat, long] vertices.
    % The shape is automatically closed (first and last points are connected).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % vertex positions as an Nx2 matrix of [lat, long] rows
        Positions (:,2) double = zeros(0,2)
    end

    methods
        function this = Polygon(props)
            arguments
                props.?ic.map.Polygon
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Path(props);
            % Polygons are filled by default
            if ~any(strcmp(fieldnames(props), 'Fill'))
                this.Fill = true;
            end
        end
    end
end
