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

        % tile cache: containers.Map(url -> struct with data, mime)
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

        function layer = addWmsLayer(this, props)
            % add a WMS (Web Map Service) tile layer
            % {returns} the new #ic.map.WmsLayer {/returns}
            arguments
                this
                % name-value pairs for #ic.map.WmsLayer properties
                props.?ic.map.WmsLayer
            end
            args = namedargs2cell(props);
            layer = ic.map.WmsLayer(args{:});
            this.insertLayer(layer);
        end

        function layer = addHeatLayer(this, props)
            % add a heatmap visualization layer
            % {returns} the new #ic.map.HeatLayer {/returns}
            arguments
                this
                % name-value pairs for #ic.map.HeatLayer properties
                props.?ic.map.HeatLayer
            end
            args = namedargs2cell(props);
            layer = ic.map.HeatLayer(args{:});
            this.insertLayer(layer);
        end

        function ctrl = addMeasureControl(this, props)
            % add a distance and area measurement tool
            % {returns} the new #ic.map.MeasureControl {/returns}
            arguments
                this
                % name-value pairs for #ic.map.MeasureControl properties
                props.?ic.map.MeasureControl
            end
            args = namedargs2cell(props);
            ctrl = ic.map.MeasureControl(args{:});
            this.insertLayer(ctrl);
        end
    end

    methods (Access = public)

        function h = plot(this, lat, lon, opts)
            % draw a line path connecting geographic coordinates.
            arguments
                this
                % latitude values
                lat (:,1) double
                % longitude values
                lon (:,1) double
                % line color: [R G B] (0-1), short name ("r"), or CSS string
                opts.Color = [0 0.4470 0.7410]
                % line width in pixels
                opts.LineWidth (1,1) double = 3
                % line style: "-" (solid), "--" (dashed), ":" (dotted), "-." (dash-dot)
                opts.LineStyle (1,1) string {mustBeMember(opts.LineStyle, ["-","--",":","-."])} = "-"
                % display name for layer control
                opts.Name (1,1) string = ""
            end
            assert(numel(lat) == numel(lon), ...
                'ic:Map:SizeMismatch', 'lat and lon must have the same number of elements.');
            h = this.addPolyline( ...
                'Positions', [lat(:), lon(:)], ...
                'Color', ic.Map.matlabColorToCss(opts.Color), ...
                'Weight', opts.LineWidth, ...
                'DashArray', ic.Map.lineStyleToDashArray(opts.LineStyle), ...
                'Name', opts.Name);
        end

        function h = polygon(this, lat, lon, opts)
            % draw a filled polygon from geographic coordinates.
            arguments
                this
                % latitude values of vertices
                lat (:,1) double
                % longitude values of vertices
                lon (:,1) double
                % edge color: [R G B], short name, or CSS string
                opts.Color = [0 0.4470 0.7410]
                % fill color (defaults to Color if empty)
                opts.FaceColor = []
                % fill opacity (0 to 1)
                opts.FaceAlpha (1,1) double = 0.2
                % edge width in pixels
                opts.LineWidth (1,1) double = 3
                % edge style: "-", "--", ":", "-."
                opts.LineStyle (1,1) string {mustBeMember(opts.LineStyle, ["-","--",":","-."])} = "-"
                % display name for layer control
                opts.Name (1,1) string = ""
            end
            assert(numel(lat) == numel(lon), ...
                'ic:Map:SizeMismatch', 'lat and lon must have the same number of elements.');
            edgeColor = ic.Map.matlabColorToCss(opts.Color);
            if isempty(opts.FaceColor)
                fillColor = ic.Map.matlabColorToCssRgba(opts.Color, opts.FaceAlpha);
            else
                fillColor = ic.Map.matlabColorToCssRgba(opts.FaceColor, opts.FaceAlpha);
            end
            h = this.addPolygon( ...
                'Positions', [lat(:), lon(:)], ...
                'Color', edgeColor, ...
                'Weight', opts.LineWidth, ...
                'DashArray', ic.Map.lineStyleToDashArray(opts.LineStyle), ...
                'Fill', true, ...
                'FillColor', fillColor, ...
                'Name', opts.Name);
        end

        function h = circle(this, lat, lon, radius, opts)
            % draw circles at geographic coordinates.
            % If lat/lon/radius are vectors, creates multiple circles.
            arguments
                this
                % latitude values
                lat (:,1) double
                % longitude values
                lon (:,1) double
                % radius in meters (scalar broadcasts to all)
                radius (:,1) double
                % edge color
                opts.Color = [0 0.4470 0.7410]
                % fill color (defaults to Color if empty)
                opts.FaceColor = []
                % fill opacity (0 to 1)
                opts.FaceAlpha (1,1) double = 0.2
                % edge width in pixels
                opts.LineWidth (1,1) double = 3
                % display name for layer control
                opts.Name (1,1) string = ""
            end
            n = numel(lat);
            assert(numel(lon) == n, ...
                'ic:Map:SizeMismatch', 'lat and lon must have the same number of elements.');
            if isscalar(radius)
                radius = repmat(radius, n, 1);
            end
            assert(numel(radius) == n, ...
                'ic:Map:SizeMismatch', 'radius must be scalar or match lat/lon length.');

            edgeColor = ic.Map.matlabColorToCss(opts.Color);
            if isempty(opts.FaceColor)
                fillColor = ic.Map.matlabColorToCssRgba(opts.Color, opts.FaceAlpha);
            else
                fillColor = ic.Map.matlabColorToCssRgba(opts.FaceColor, opts.FaceAlpha);
            end

            h = ic.map.Circle.empty(0, 1);
            for i = 1:n
                h(i) = this.addCircle( ...
                    'Center', [lat(i), lon(i)], ...
                    'Radius', radius(i), ...
                    'Color', edgeColor, ...
                    'Weight', opts.LineWidth, ...
                    'Fill', true, ...
                    'FillColor', fillColor, ...
                    'Name', opts.Name);
            end
        end

        function h = scatter(this, lat, lon, opts)
            % plot point markers at geographic coordinates.
            arguments
                this
                % latitude values
                lat (:,1) double
                % longitude values
                lon (:,1) double
                % marker icon name (applied to all markers)
                opts.Marker (1,1) string = "pin"
                % marker size as [width, height] in pixels
                opts.MarkerSize (1,2) double = [25, 41]
                % marker opacity (scalar broadcasts to all)
                opts.Opacity (:,1) double = 1.0
                % popup text per marker (string array, same length as lat)
                opts.Label (:,1) string = strings(0, 1)
                % tooltip text per marker (string array, same length as lat)
                opts.Tooltip (:,1) string = strings(0, 1)
                % whether markers are draggable
                opts.Draggable (1,1) logical = false
                % display name for layer control
                opts.Name (1,1) string = ""
            end
            n = numel(lat);
            assert(numel(lon) == n, ...
                'ic:Map:SizeMismatch', 'lat and lon must have the same number of elements.');
            if n > 1000
                warning('ic:Map:LargeScatter', ...
                    'Creating %d individual markers. For large datasets consider heatmap() or geojson().', n);
            end

            if isscalar(opts.Opacity)
                opacities = repmat(opts.Opacity, n, 1);
            else
                assert(numel(opts.Opacity) == n, ...
                    'ic:Map:SizeMismatch', 'Opacity must be scalar or match lat/lon length.');
                opacities = opts.Opacity;
            end
            hasLabels = ~isempty(opts.Label) && numel(opts.Label) == n;
            hasTooltips = ~isempty(opts.Tooltip) && numel(opts.Tooltip) == n;

            h = ic.map.Marker.empty(0, 1);
            for i = 1:n
                args = { ...
                    'Position', [lat(i), lon(i)], ...
                    'Icon', opts.Marker, ...
                    'IconSize', opts.MarkerSize, ...
                    'Opacity', opacities(i), ...
                    'Draggable', opts.Draggable};
                if hasLabels && strlength(opts.Label(i)) > 0
                    args = [args, {'PopupContent', opts.Label(i)}]; %#ok<AGROW>
                end
                if hasTooltips && strlength(opts.Tooltip(i)) > 0
                    args = [args, {'TooltipContent', opts.Tooltip(i)}]; %#ok<AGROW>
                end
                marker = ic.map.Marker(args{:});
                if opts.Name ~= ""
                    marker.Name = opts.Name;
                end
                this.insertLayer(marker);
                h(i) = marker;
            end
        end

        function h = heatmap(this, lat, lon, opts)
            % create a heatmap visualization from point data.
            arguments
                this
                % latitude values
                lat (:,1) double
                % longitude values
                lon (:,1) double
                % per-point intensity values (optional)
                opts.Intensity (:,1) double = double.empty(0, 1)
                % point radius in pixels
                opts.Radius (1,1) double = 25
                % blur size in pixels
                opts.Blur (1,1) double = 15
                % MATLAB colormap name for the gradient
                opts.Colormap (1,1) string = ""
                % display name for layer control
                opts.Name (1,1) string = ""
            end
            assert(numel(lat) == numel(lon), ...
                'ic:Map:SizeMismatch', 'lat and lon must have the same number of elements.');

            if isempty(opts.Intensity)
                data = [lat(:), lon(:)];
            else
                assert(numel(opts.Intensity) == numel(lat), ...
                    'ic:Map:SizeMismatch', 'Intensity must match lat/lon length.');
                data = [lat(:), lon(:), opts.Intensity(:)];
            end

            args = {'Data', data, 'Radius', opts.Radius, 'Blur', opts.Blur};
            if opts.Colormap ~= ""
                [pos, clrs] = ic.Map.colormapToGradient(opts.Colormap);
                args = [args, {'GradientPositions', pos, 'GradientColors', clrs}];
            end
            if opts.Name ~= ""
                args = [args, {'Name', opts.Name}];
            end
            h = this.addHeatLayer(args{:});
        end

        function h = geojson(this, data, opts)
            % display GeoJSON data on the map.
            % Accepts a struct (from jsondecode), or a file path string.
            arguments
                this
                % GeoJSON data: struct or file path
                data
                % default edge color
                opts.Color = [0.2 0.33 1]
                % fill opacity (0 to 1)
                opts.FaceAlpha (1,1) double = 0.2
                % edge width in pixels
                opts.LineWidth (1,1) double = 3
                % per-feature style function: @(feature) -> struct
                opts.StyleFcn = []
                % per-feature highlight function: @(feature) -> struct
                opts.HighlightFcn = []
                % per-feature popup function: @(feature) -> string
                opts.PopupFcn = []
                % per-feature tooltip function: @(feature) -> string
                opts.TooltipFcn = []
                % display name for layer control
                opts.Name (1,1) string = ""
            end

            % Load from file if string path
            if (ischar(data) || isstring(data))
                path = string(data);
                assert(isfile(path), 'ic:Map:FileNotFound', ...
                    'GeoJSON file not found: %s', path);
                data = jsondecode(fileread(path));
            end

            edgeColor = ic.Map.matlabColorToCss(opts.Color);
            h = this.addGeoJSON( ...
                'Data', data, ...
                'Color', edgeColor, ...
                'Weight', opts.LineWidth, ...
                'FillOpacity', opts.FaceAlpha, ...
                'Name', opts.Name);

            if ~isempty(opts.StyleFcn)
                h.StyleFcn = opts.StyleFcn;
            end
            if ~isempty(opts.HighlightFcn)
                h.HighlightFcn = opts.HighlightFcn;
            end
            if ~isempty(opts.PopupFcn)
                h.PopupFcn = opts.PopupFcn;
            end
            if ~isempty(opts.TooltipFcn)
                h.TooltipFcn = opts.TooltipFcn;
            end
        end

        function h = image(this, img, bounds, opts)
            % overlay an image on geographic bounds.
            arguments
                this
                % image source: file path, URL, or ic.Asset
                img
                % geographic bounds as [[south,west];[north,east]]
                bounds (2,2) double
                % overlay opacity (0 to 1)
                opts.Opacity (1,1) double = 1.0
                % display name for layer control
                opts.Name (1,1) string = ""
            end
            h = this.addImageOverlay( ...
                'Image', img, ...
                'Bounds', bounds, ...
                'Opacity', opts.Opacity, ...
                'Name', opts.Name);
        end

        function geolimits(this, latlim, lonlim)
            % set the map view to geographic limits.
            arguments
                this
                % latitude limits as [south, north]
                latlim (1,2) double
                % longitude limits as [west, east]
                lonlim (1,2) double
            end
            this.fitBounds([latlim(1), lonlim(1); latlim(2), lonlim(2)]);
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

    methods (Static, Access = private, Hidden)
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

        function css = matlabColorToCss(c)
            % convert a MATLAB color spec to a CSS hex string.
            % Accepts [R G B] (0-1), short name ("r","g"), or CSS passthrough ("#ff0000").
            if isnumeric(c) && numel(c) == 3
                css = sprintf("#%02x%02x%02x", ...
                    round(c(1)*255), round(c(2)*255), round(c(3)*255));
            elseif ischar(c) || isstring(c)
                c = char(c);
                shorts = struct( ...
                    'r','#ff0000', 'g','#00ff00', 'b','#0000ff', ...
                    'c','#00ffff', 'm','#ff00ff', 'y','#ffff00', ...
                    'k','#000000', 'w','#ffffff');
                if isscalar(c) && isfield(shorts, c)
                    css = string(shorts.(c));
                else
                    css = string(c);
                end
            else
                css = "#3388ff";
            end
        end

        function css = matlabColorToCssRgba(c, alpha)
            % convert a MATLAB color spec + alpha to a CSS rgba() string.
            if isnumeric(c) && numel(c) == 3
                rgb = round(c * 255);
            elseif ischar(c) || isstring(c)
                hex = ic.Map.matlabColorToCss(c);
                hex = char(hex);
                hex = hex(2:end);
                rgb = [hex2dec(hex(1:2)), hex2dec(hex(3:4)), hex2dec(hex(5:6))];
            else
                rgb = [51, 136, 255];
            end
            css = sprintf("rgba(%d,%d,%d,%.4g)", rgb(1), rgb(2), rgb(3), alpha);
        end

        function da = lineStyleToDashArray(style)
            % convert a MATLAB line style to a CSS dash-array string.
            switch style
                case "-",  da = "";
                case "--", da = "10 5";
                case ":",  da = "2 5";
                case "-.", da = "10 5 2 5";
                otherwise, da = "";
            end
        end

        function [positions, colors] = colormapToGradient(name, n)
            % sample a MATLAB colormap into n gradient stops.
            arguments
                name (1,1) string
                n (1,1) double = 5
            end
            try
                cmap = feval(name, n);
            catch
                cmap = [0 0 1; 0 1 0; 1 0 0];
                n = 3;
            end
            positions = linspace(0, 1, n);
            colors = strings(1, n);
            for i = 1:n
                colors(i) = ic.Map.matlabColorToCss(cmap(i,:));
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

                % Detect mime: prefer explicit field (WMS), fall back to extension
                if isfield(data, 'mime') && strlength(string(data.mime)) > 0
                    mime = string(data.mime);
                else
                    [~, ~, ext] = fileparts(regexprep(tileUrl, '\?.*$', ''));
                    mime = ic.Map.mimeFromExt(ext);
                end

                result = struct('data', b64, 'mime', mime);
                this.TileCache(cacheKey) = result;
            catch ex
                error('ic:Map:tileFetchFailed', ...
                    'Failed to fetch tile %s: %s', cacheKey, ex.message);
            end
        end
    end
end
