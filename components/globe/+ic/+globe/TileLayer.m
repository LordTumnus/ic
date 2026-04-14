classdef TileLayer < ic.globe.Layer
    % raster imagery tile layer for the 3D globe
    % Use a built-in provider preset or supply a custom URL template with {z}/{x}/{y} placeholders.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % built-in provider preset name
        Provider (1,1) string {mustBeMember(Provider, [ ...
            "openstreetmap", "cartodb-light", "cartodb-dark", ...
            "opentopomap", "osm-humanitarian", ...
            "esri-worldimagery", "esri-worldtopomap"])} = "openstreetmap"

        % custom URL template with {z}/{x}/{y} placeholders. Overrides #ic.globe.TileLayer.Provider when set.
        Url (1,1) string = ""

        % layer opacity (0 to 1)
        Opacity (1,1) double = 1.0

        % maximum zoom level the provider serves
        MaximumLevel (1,1) double = 19
    end

    methods
        function this = TileLayer(props)
            arguments
                props.?ic.globe.TileLayer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.globe.Layer(props);
        end
    end
end
