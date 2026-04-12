classdef ImageOverlay < ic.map.Layer
    % displays an image over geographic bounds on a Leaflet map.
    % The image source is provided via a file path or URL.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % image source asset (file path, URL, or empty)
        Image ic.Asset = ic.Asset("")

        % geographic bounds as [[south,west];[north,east]]
        Bounds (2,2) double = [0, 0; 0, 0]

        % overlay opacity (0 to 1)
        Opacity (1,1) double = 1.0

        % stacking order relative to other overlays
        ZIndex (1,1) double = 1
    end

    methods
        function this = ImageOverlay(props)
            arguments
                props.?ic.map.ImageOverlay
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end
    end
end
