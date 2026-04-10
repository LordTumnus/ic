classdef ScaleControl < ic.map.Control
    % distance scale bar displayed on the map.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % maximum width of the scale bar in pixels
        MaxWidth (1,1) double = 100

        % whether to show metric units (m/km)
        Metric (1,1) logical = true

        % whether to show imperial units (ft/mi)
        Imperial (1,1) logical = true
    end

    methods
        function this = ScaleControl(props)
            arguments
                props.?ic.map.ScaleControl
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Control(props);
            if ~any(strcmp(fieldnames(props), 'Position'))
                this.Position = "bottomleft";
            end
        end
    end
end
