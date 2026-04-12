classdef GeoJSON < ic.map.Layer
    % renders a GeoJSON FeatureCollection on a Leaflet map.
    % Supports per-feature styling via function handles and interactive
    % highlighting on hover.
    % Data accepts the output of jsondecode(fileread('file.geojson')),
    % or any struct conforming to the GeoJSON specification.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % GeoJSON FeatureCollection as a MATLAB struct
        Data (1,1) struct = struct()

        % default stroke color (CSS color string)
        Color (1,1) string = "#3388ff"

        % default stroke width in pixels
        Weight (1,1) double = 3

        % whether polygons have a fill
        Fill (1,1) logical = true

        % fill color (defaults to Color if empty)
        FillColor (1,1) string = ""

        % fill opacity (0 to 1)
        FillOpacity (1,1) double = 0.2

        % radius in pixels for GeoJSON Point features rendered as circle markers
        PointRadius (1,1) double = 8
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % precomputed per-feature styles (cell array of structs).
        % Populated automatically when StyleFcn is set and Data changes.
        FeatureStyles = {}

        % precomputed per-feature highlight styles (cell array of structs).
        % Populated automatically when HighlightFcn is set and Data changes.
        FeatureHighlightStyles = {}

        % precomputed per-feature popup HTML strings (cell array of strings).
        % Populated automatically when PopupFcn is set and Data changes.
        FeaturePopups = {}

        % precomputed per-feature tooltip HTML strings (cell array of strings).
        % Populated automatically when TooltipFcn is set and Data changes.
        FeatureTooltips = {}
    end

    properties (AbortSet)
        % per-feature style function handle.
        % Signature: @(feature) -> struct with optional fields:
        %   color, weight, opacity, fillColor, fillOpacity, dashArray
        % where feature is a struct with .type, .geometry, .properties
        StyleFcn = []

        % per-feature highlight style function handle applied on hover.
        % Same signature as StyleFcn.
        HighlightFcn = []

        % per-feature popup content function handle.
        % Signature: @(feature) -> string (HTML content for the popup)
        PopupFcn = []

        % per-feature tooltip content function handle.
        % Signature: @(feature) -> string (HTML content for the tooltip)
        TooltipFcn = []
    end

    events (Description = "Reactive")
        % fires when the user clicks a feature
        % {payload}
        % featureId   | string: feature id or index
        % properties  | struct: the feature's properties object
        % latlng      | 1x2 double: [lat, lng] of the click
        % {/payload}
        FeatureClick

        % fires when the mouse enters a feature
        % {payload}
        % featureId   | string: feature id or index
        % properties  | struct: the feature's properties object
        % latlng      | 1x2 double: [lat, lng] of the mouse
        % {/payload}
        FeatureMouseOver

        % fires when the mouse leaves a feature
        % {payload}
        % featureId  | string: feature id or index
        % properties | struct: the feature's properties object
        % {/payload}
        FeatureMouseOut
    end

    methods (Description = "Reactive")
        function out = fitBounds(this)
            % zoom the map to fit the GeoJSON extent
            out = this.publish("fitBounds", []);
        end

        function out = resetStyle(this)
            % reset all features to their default styling
            out = this.publish("resetStyle", []);
        end
    end

    methods
        function this = GeoJSON(props)
            arguments
                props.?ic.map.GeoJSON
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
            this.recomputeAll();
        end

        function set.StyleFcn(this, val)
            if ~isempty(val)
                assert(isa(val, 'function_handle'), ...
                    'ic:map:GeoJSON:InvalidStyleFcn', ...
                    'StyleFcn must be a function handle or empty');
            end
            this.StyleFcn = val;
            this.recomputeStyles();
        end

        function set.HighlightFcn(this, val)
            if ~isempty(val)
                assert(isa(val, 'function_handle'), ...
                    'ic:map:GeoJSON:InvalidHighlightFcn', ...
                    'HighlightFcn must be a function handle or empty');
            end
            this.HighlightFcn = val;
            this.recomputeHighlightStyles();
        end

        function set.PopupFcn(this, val)
            if ~isempty(val)
                assert(isa(val, 'function_handle'), ...
                    'ic:map:GeoJSON:InvalidPopupFcn', ...
                    'PopupFcn must be a function handle or empty');
            end
            this.PopupFcn = val;
            this.recomputePopups();
        end

        function set.TooltipFcn(this, val)
            if ~isempty(val)
                assert(isa(val, 'function_handle'), ...
                    'ic:map:GeoJSON:InvalidTooltipFcn', ...
                    'TooltipFcn must be a function handle or empty');
            end
            this.TooltipFcn = val;
            this.recomputeTooltips();
        end

        function set.Data(this, val)
            this.Data = val; %#ok<MCSUP>
            this.recomputeAll(); %#ok<MCSUP>
        end
    end

    methods (Access = private)
        function recomputeAll(this)
            this.recomputeStyles();
            this.recomputeHighlightStyles();
            this.recomputePopups();
            this.recomputeTooltips();
        end

        function recomputeStyles(this)
            if isempty(this.StyleFcn) || ~isfield(this.Data, 'features')
                this.FeatureStyles = {};
                return;
            end
            this.FeatureStyles = this.evalFcnPerFeature(this.StyleFcn, struct());
        end

        function recomputeHighlightStyles(this)
            if isempty(this.HighlightFcn) || ~isfield(this.Data, 'features')
                this.FeatureHighlightStyles = {};
                return;
            end
            this.FeatureHighlightStyles = this.evalFcnPerFeature(this.HighlightFcn, struct());
        end

        function recomputePopups(this)
            if isempty(this.PopupFcn) || ~isfield(this.Data, 'features')
                this.FeaturePopups = {};
                return;
            end
            this.FeaturePopups = this.evalFcnPerFeature(this.PopupFcn, "");
        end

        function recomputeTooltips(this)
            if isempty(this.TooltipFcn) || ~isfield(this.Data, 'features')
                this.FeatureTooltips = {};
                return;
            end
            this.FeatureTooltips = this.evalFcnPerFeature(this.TooltipFcn, "");
        end

        function results = evalFcnPerFeature(this, fcn, fallback)
            features = this.Data.features;
            n = numel(features);
            results = cell(1, n);
            for i = 1:n
                try
                    results{i} = fcn(features(i));
                catch
                    results{i} = fallback;
                end
            end
        end
    end
end
