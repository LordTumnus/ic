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

        % Cesium Ion access token. Required for Ion-hosted assets like Cesium World Terrain (#ic.globe.Terrain) and Cesium OSM Buildings.
        IonToken (1,1) string = ""
    end

    properties (SetAccess = private)
        % child #ic.globe.Camera controlling the view
        Camera

        % child #ic.globe.Terrain controlling 3D elevation
        Terrain
    end

    properties (Access = private, Hidden)
        % monotonic counter for stable child ordering
        NextLayerIndex (1,1) double = 0
    end

    methods
        function this = Globe(props)
            arguments
                props.?ic.Globe
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);

            % register binary request handlers
            this.onBinaryRequest("tile", @(comp, data) comp.handleGetTile(data));
            this.onBinaryRequest("terrain", @(comp, data) comp.handleGetHttpBytes(data));
            this.onBinaryRequest("tileset3d", @(comp, data) comp.handleGetHttpBytes(data));

            % JSON request handler for Cesium Ion asset endpoint resolution.
            this.onRequest("resolveIonAsset", @(comp, data) comp.handleResolveIonAsset(data));

            % attach the camera child
            this.Camera = ic.globe.Camera();
            this.addChild(this.Camera);

            % attach the terrain child (singleton; defaults to disabled)
            this.Terrain = ic.globe.Terrain();
            this.addChild(this.Terrain);
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

        function layer = addTileset3D(this, props)
            % add a streaming 3D Tiles layer (photogrammetry, buildings, point clouds).
            % {returns} the new #ic.globe.Tileset3D {/returns}
            arguments
                this
                % name-value pairs for #ic.globe.Tileset3D properties
                props.?ic.globe.Tileset3D
            end
            args = namedargs2cell(props);
            layer = ic.globe.Tileset3D(args{:});
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
            raw = this.handleGetHttpBytes(data);
        end

        function raw = handleGetHttpBytes(~, data)
            url = string(data.url);
            opts = weboptions('ContentType', 'binary', 'Timeout', 30);
            raw = webread(url, opts);
        end

        function result = handleResolveIonAsset(this, data)
            if this.IonToken == ""
                error("ic:Globe:noIonToken", ...
                    "IonToken is empty; set g.IonToken before using Ion-hosted assets.");
            end
            assetId = double(data.assetId);
            url = sprintf('https://api.cesium.com/v1/assets/%d/endpoint', assetId);
            opts = weboptions( ...
                'HeaderFields', {'Authorization', sprintf('Bearer %s', this.IonToken)}, ...
                'ContentType', 'json', ...
                'Timeout', 15);
            result = webread(url, opts);
        end
    end
end
