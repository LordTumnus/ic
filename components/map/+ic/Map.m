classdef Map < ic.core.ComponentContainer & ic.mixin.Requestable
    % interactive map powered by [Leaflet.js](https://leafletjs.com/).
    % Add layers and controls to build a geospatial visualization.
    % Tiles are fetched through MATLAB's webread and proxied to the frontend.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % map center as [lat, long]
        Center (1,2) double = [51.505, -0.09]

        % current zoom level
        Zoom (1,1) double = 13

        % minimum allowed zoom level
        MinZoom (1,1) double = 0

        % maximum allowed zoom level
        MaxZoom (1,1) double = 19

        % restrict the map viewport to these bounds as [[south,west];[north,east]], or empty for no restriction
        MaxBounds double = []

        % whether the built-in zoom buttons are shown
        ZoomControl (1,1) logical = true

        % whether the user can drag the map
        AllowDragging (1,1) logical = true

        % whether the scroll wheel zooms the map
        ScrollWheelZoom (1,1) logical = true

        % whether double-clicking zooms the map
        DoubleClickZoom (1,1) logical = true

        % whether keyboard arrows and +/- navigate the map
        Keyboard (1,1) logical = true

        % css height of the map container
        Height (1,1) string = "400px"
    end

    events (Description = "Reactive")
        % fires when the user clicks the map
        % {payload}
        % latlng | 1x2 double: [lat, lng] of the clicked point
        % {/payload}
        Click

        % fires when the user double-clicks the map
        % {payload}
        % latlng | 1x2 double: [lat, lng] of the double-clicked point
        % {/payload}
        DoubleClick

        % fires after the map finishes panning or zooming
        % {payload}
        % center | 1x2 double: [lat, lng] of the new center
        % zoom   | double: new zoom level
        % bounds | 2x2 double: [[south,west];[north,east]]
        % {/payload}
        MoveEnd

        % fires after the map finishes a zoom animation
        % {payload}
        % zoom | double: new zoom level
        % {/payload}
        ZoomEnd
    end

    methods (Description = "Reactive")
        function out = setView(this, center, zoom)
            % animate the map to a new center and zoom level
            arguments
                this
                % [lat, lng] target center
                center (1,2) double
                % target zoom level
                zoom (1,1) double
            end
            out = this.publish("setView", struct('center', center, 'zoom', zoom));
        end

        function out = panTo(this, latlng)
            % smooth pan to a position
            arguments
                this
                % [lat, lng] target position
                latlng (1,2) double
            end
            out = this.publish("panTo", struct('latlng', latlng));
        end

        function out = fitBounds(this, bounds)
            % fit the map to geographic bounds
            arguments
                this
                % [[south,west];[north,east]] bounds
                bounds (2,2) double
            end
            out = this.publish("fitBounds", struct('bounds', bounds));
        end

        function out = zoomIn(this)
            % zoom in by one level
            out = this.publish("zoomIn", []);
        end

        function out = zoomOut(this)
            % zoom out by one level
            out = this.publish("zoomOut", []);
        end

        function out = invalidateSize(this)
            % recalculate map size after its container has been resized
            out = this.publish("invalidateSize", []);
        end
    end

    properties (Access = private, Hidden)
        % monotonic counter for stable child ordering
        NextLayerIndex (1,1) double = 0

        % tile cache: containers.Map(url → struct with data, mime)
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

        function layer = addMarker(this, props)
            % add a point marker
            % {returns} the new #ic.map.Marker {/returns}
            arguments
                this
                % name-value pairs for #ic.map.Marker properties
                props.?ic.map.Marker
            end
            args = namedargs2cell(props);
            layer = ic.map.Marker(args{:});
            this.insertLayer(layer);
        end

        function layer = addPolyline(this, props)
            % add a line path
            % {returns} the new #ic.map.Polyline {/returns}
            arguments
                this
                % name-value pairs for #ic.map.Polyline properties
                props.?ic.map.Polyline
            end
            args = namedargs2cell(props);
            layer = ic.map.Polyline(args{:});
            this.insertLayer(layer);
        end

        function layer = addPolygon(this, props)
            % add a closed polygon
            % {returns} the new #ic.map.Polygon {/returns}
            arguments
                this
                % name-value pairs for #ic.map.Polygon properties
                props.?ic.map.Polygon
            end
            args = namedargs2cell(props);
            layer = ic.map.Polygon(args{:});
            this.insertLayer(layer);
        end

        function layer = addCircle(this, props)
            % add a circle with radius in meters
            % {returns} the new #ic.map.Circle {/returns}
            arguments
                this
                % name-value pairs for #ic.map.Circle properties
                props.?ic.map.Circle
            end
            args = namedargs2cell(props);
            layer = ic.map.Circle(args{:});
            this.insertLayer(layer);
        end

        function layer = addRectangle(this, props)
            % add an axis-aligned rectangle
            % {returns} the new #ic.map.Rectangle {/returns}
            arguments
                this
                % name-value pairs for #ic.map.Rectangle properties
                props.?ic.map.Rectangle
            end
            args = namedargs2cell(props);
            layer = ic.map.Rectangle(args{:});
            this.insertLayer(layer);
        end

        function layer = addLayerGroup(this, props)
            % add a layer group to organize child layers
            % {returns} the new #ic.map.LayerGroup {/returns}
            arguments
                this
                % name-value pairs for #ic.map.LayerGroup properties
                props.?ic.map.LayerGroup
            end
            args = namedargs2cell(props);
            layer = ic.map.LayerGroup(args{:});
            this.insertLayer(layer);
        end

        function layer = addFeatureGroup(this, props)
            % add a feature group with event propagation and fitBounds support
            % {returns} the new #ic.map.FeatureGroup {/returns}
            arguments
                this
                % name-value pairs for #ic.map.FeatureGroup properties
                props.?ic.map.FeatureGroup
            end
            args = namedargs2cell(props);
            layer = ic.map.FeatureGroup(args{:});
            this.insertLayer(layer);
        end

        function layer = addGeoJSON(this, props)
            % add a GeoJSON feature collection layer
            % {returns} the new #ic.map.GeoJSON {/returns}
            arguments
                this
                % name-value pairs for #ic.map.GeoJSON properties
                props.?ic.map.GeoJSON
            end
            args = namedargs2cell(props);
            layer = ic.map.GeoJSON(args{:});
            this.insertLayer(layer);
        end

        function layer = addImageOverlay(this, props)
            % add an image overlay on geographic bounds
            % {returns} the new #ic.map.ImageOverlay {/returns}
            arguments
                this
                % name-value pairs for #ic.map.ImageOverlay properties
                props.?ic.map.ImageOverlay
            end
            args = namedargs2cell(props);
            layer = ic.map.ImageOverlay(args{:});
            this.insertLayer(layer);
        end

        function layer = addDivMarker(this, props)
            % add a custom HTML marker (can hold IC child components)
            % {returns} the new #ic.map.DivMarker {/returns}
            arguments
                this
                % name-value pairs for #ic.map.DivMarker properties
                props.?ic.map.DivMarker
            end
            args = namedargs2cell(props);
            layer = ic.map.DivMarker(args{:});
            this.insertLayer(layer);
        end

        function layer = addPopup(this, props)
            % add a standalone popup at a fixed geographic position
            % {returns} the new #ic.map.Popup {/returns}
            arguments
                this
                % name-value pairs for #ic.map.Popup properties
                props.?ic.map.Popup
            end
            args = namedargs2cell(props);
            layer = ic.map.Popup(args{:});
            this.insertLayer(layer);
        end

        function layer = addTooltip(this, props)
            % add a standalone tooltip at a fixed geographic position
            % {returns} the new #ic.map.Tooltip {/returns}
            arguments
                this
                % name-value pairs for #ic.map.Tooltip properties
                props.?ic.map.Tooltip
            end
            args = namedargs2cell(props);
            layer = ic.map.Tooltip(args{:});
            this.insertLayer(layer);
        end

        function ctrl = addScaleControl(this, props)
            % add a distance scale bar
            % {returns} the new #ic.map.ScaleControl {/returns}
            arguments
                this
                % name-value pairs for #ic.map.ScaleControl properties
                props.?ic.map.ScaleControl
            end
            args = namedargs2cell(props);
            ctrl = ic.map.ScaleControl(args{:});
            this.insertLayer(ctrl);
        end

        function ctrl = addCoordinateDisplay(this, props)
            % add a cursor coordinate readout control
            % {returns} the new #ic.map.CoordinateDisplay {/returns}
            arguments
                this
                % name-value pairs for #ic.map.CoordinateDisplay properties
                props.?ic.map.CoordinateDisplay
            end
            args = namedargs2cell(props);
            ctrl = ic.map.CoordinateDisplay(args{:});
            this.insertLayer(ctrl);
        end

        function ctrl = addLayersControl(this, props)
            % add a layer visibility toggle control
            % {returns} the new #ic.map.LayersControl {/returns}
            arguments
                this
                % name-value pairs for #ic.map.LayersControl properties
                props.?ic.map.LayersControl
            end
            args = namedargs2cell(props);
            ctrl = ic.map.LayersControl(args{:});
            this.insertLayer(ctrl);
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
