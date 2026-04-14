classdef Globe < ic.core.ComponentContainer & ...
                  ic.mixin.Requestable & ...
                  ic.mixin.BinaryChannel
    % 3D interactive globe powered by [CesiumJS](https://cesium.com/).
    % Add layers and controls to build a geospatial 3D visualization. Tiles and terrain are fetched through MATLAB's webread and streamed to the frontend via the BinaryChannel mixin.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % css height of the globe container
        Height (1,1) string = "400px"

        % scene mode -- "3D" for a globe, "2D" for a top-down map, "Columbus" for 2.5D
        SceneMode string {mustBeMember(SceneMode, ["3D", "2D", "Columbus"])} = "3D"

        % whether the sky atmosphere (blue halo around the globe) is rendered
        EnableAtmosphere (1,1) logical = true
    end

    properties (SetAccess = private)
        % child #ic.globe.Camera controlling the view
        Camera
    end

    properties (Access = private, Hidden)
        % monotonic counter for stable child ordering
        NextLayerIndex (1,1) double = 0

        % tile cache: containers.Map(url -> uint8 bytes)
        TileCache
    end

    methods
        function this = Globe(props)
            arguments
                props.?ic.Globe
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.TileCache = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % register the binary tile request handler
            this.onBinaryRequest("tile", @(comp, data) comp.handleGetTile(data));

            % attach the camera child
            this.Camera = ic.globe.Camera();
            this.addChild(this.Camera);
        end
    end

    methods (Access = public)
        function layer = addTileLayer(this, props)
            % add an imagery tile layer.
            % {returns} the new #ic.globe.TileLayer {/returns}
            arguments
                this
                % name-value pairs for #ic.globe.TileLayer properties
                props.?ic.globe.TileLayer
            end
            args = namedargs2cell(props);
            layer = ic.globe.TileLayer(args{:});
            this.insertLayer(layer);
        end
    end

    methods (Access = protected)
        function insertLayer(this, layer)
            % assigns a stable layer index and registers as a child.
            idx = this.NextLayerIndex;
            this.NextLayerIndex = idx + 1;
            layer.LayerIndex = idx;
            this.addChild(layer);
        end
    end

    methods (Access = private)
        function raw = handleGetTile(this, data)
            % fetch one tile via webread, cache by URL, return raw uint8 bytes.
            tileUrl = string(data.url);
            cacheKey = char(tileUrl);

            if this.TileCache.isKey(cacheKey)
                raw = this.TileCache(cacheKey);
                return;
            end

            opts = weboptions('ContentType', 'binary', 'Timeout', 10);
            raw = webread(tileUrl, opts);
            this.TileCache(cacheKey) = raw;
        end
    end
end
