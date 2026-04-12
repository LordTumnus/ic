classdef WmsLayer < ic.map.Layer
    % WMS (Web Map Service) tile layer fetched through MATLAB's webread proxy.
    % Only Url and Layers are required; all other parameters have sensible defaults.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % WMS base URL (e.g. "https://server.org/wms")
        Url (1,1) string = ""

        % WMS layer names, comma-separated (e.g. "roads,rivers")
        Layers (1,1) string = ""

        % SLD named styles (comma-separated, matching Layers order)
        WmsStyles (1,1) string = ""

        % requested image format
        Format (1,1) string = "image/png"

        % whether tiles should have transparency
        Transparent (1,1) logical = true

        % WMS protocol version
        Version (1,1) string = "1.1.1"

        % tile layer opacity (0 to 1)
        Opacity (1,1) double = 1.0

        % tile pixel size
        TileSize (1,1) double = 256

        % coordinate reference system identifier
        Crs (1,1) string = "EPSG:3857"
    end

    events (Description = "Reactive")
        % fires when visible tiles start loading
        FetchStart

        % fires when all visible tiles have finished loading
        FetchEnd
    end

    methods (Description = "Reactive")
        function out = refresh(this)
            % force re-fetch of all WMS tiles (clears cache, redraws)
            out = this.publish("refresh", []);
        end
    end

    methods
        function this = WmsLayer(props)
            arguments
                props.?ic.map.WmsLayer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end
    end
end
