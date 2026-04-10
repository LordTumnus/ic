classdef Rectangle < ic.map.Path
    % axis-aligned rectangle on a Leaflet map defined by geographic bounds.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % geographic bounds as [[south, west]; [north, east]]
        Bounds (2,2) double = [0,0; 0,0]
    end

    methods
        function this = Rectangle(props)
            arguments
                props.?ic.map.Rectangle
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Path(props);
            if ~any(strcmp(fieldnames(props), 'Fill'))
                this.Fill = true;
            end
        end
    end
end
