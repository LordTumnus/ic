classdef Map < ic.core.ComponentContainer & ic.mixin.Requestable
    % interactive map powered by [Leaflet.js](https://leafletjs.com/).
    % Add layers and controls to build a geospatial visualization.
    % Tiles are fetched through MATLAB's webread and proxied to the frontend.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % map center as [lat, long]
        Center (1,2) double = [51.505, -0.09]

        % current zoom level
        Zoom (1,1) double = 13

        % css height of the map container
        Height (1,1) string = "400px"
    end

    properties (Access = private, Hidden)
        % monotonic counter for stable child ordering
        NextLayerIndex (1,1) double = 0
    end

    methods
        function this = Map(props)
            arguments
                props.?ic.Map
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end

    methods (Access = protected)
        function insertLayer(this, layer)
            % assigns index and registers child
            idx = this.NextLayerIndex;
            this.NextLayerIndex = idx + 1;
            layer.LayerIndex = idx;
            this.addChild(layer);
        end
    end
end
