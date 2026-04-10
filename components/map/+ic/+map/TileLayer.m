classdef TileLayer < ic.map.Layer
    % raster tile layer fetched through MATLAB's webread proxy.
    % Use a built-in provider preset or supply a custom URL template
    % with {s}, {z}, {x}, {y} placeholders.
    %
    % Built-in providers:
    %  - OpenStreetMap
    %  - CartoDB Positron (light and dark variants)
    %  - OpenTopoMap topographic tiles
    %  - Humanitarian OSM Team
    %  - Esri (satellite and topographic)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % built-in provider name
        Provider (1,1) string {mustBeMember(Provider, [ ...
            "openstreetmap", "cartodb-light", "cartodb-dark", ...
            "opentopomap", "osm-humanitarian", ...
            "esri-worldimagery", "esri-worldtopomap"])} = "openstreetmap"

        % custom URL template with {s},{z},{x},{y} placeholders. It overrides #ic.map.TileLayer.Provider when set. Use it for providers that require an access token or API key.
        Url (1,1) string = ""

        % subdomain rotation characters for {s} placeholder
        Subdomains (1,1) string = "abc"

        % tile pixel size
        TileSize (1,1) double = 256

        % maximum zoom at which the provider has native tiles
        MaxNativeZoom (1,1) double = 19
    end

    methods
        function this = TileLayer(props)
            arguments
                props.?ic.map.TileLayer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end
    end
end
