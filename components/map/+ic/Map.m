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

        % tile cache: containers.Map("z/x/y" → struct with data, mime)
        TileCache
    end

    methods
        function this = Map(props)
            arguments
                props.?ic.Map
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.TileCache = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % Register tile request handler
            this.onRequest("getTile", @(comp, data) comp.handleGetTile(data));
        end
    end

    methods (Access = public)
        function layer = addTileLayer(this, props)
            % add a raster tile layer
            % {returns} the new #ic.map.TileLayer {/returns}
            arguments
                this
                % name-value pairs for #ic.map.TileLayer properties
                props.?ic.map.TileLayer
            end
            args = namedargs2cell(props);
            layer = ic.map.TileLayer(args{:});
            this.insertLayer(layer);
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

    methods (Static, Access = private)
        function mime = mimeFromExt(ext)
            % map a file extension to a MIME type for common tile formats.
            ext = lower(ext);
            switch ext
                case ".png",  mime = "image/png";
                case ".jpg",  mime = "image/jpeg";
                case ".jpeg", mime = "image/jpeg";
                case ".webp", mime = "image/webp";
                otherwise,    mime = "image/png";
            end
        end
    end

    methods (Access = private)
        function result = handleGetTile(this, data)
            % fetch a single tile via webread, cache it, return base64
            tileUrl = string(data.url);
            cacheKey = char(tileUrl);

            if this.TileCache.isKey(cacheKey)
                result = this.TileCache(cacheKey);
                return;
            end

            try
                opts = weboptions('ContentType', 'binary', 'Timeout', 10);
                raw = webread(tileUrl, opts);
                b64 = string(matlab.net.base64encode(raw));

                % Detect mime from URL extension
                [~, ~, ext] = fileparts(regexprep(tileUrl, '\?.*$', ''));
                mime = ic.Map.mimeFromExt(ext);

                result = struct('data', b64, 'mime', mime);
                this.TileCache(cacheKey) = result;
            catch ex
                error('ic:Map:tileFetchFailed', ...
                    'Failed to fetch tile %s: %s', cacheKey, ex.message);
            end
        end
    end
end
