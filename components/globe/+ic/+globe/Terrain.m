classdef Terrain < ic.core.Component
    % 3D elevation provider for the globe. Mirrors the [CesiumJS TerrainProvider](https://cesium.com/learn/cesiumjs/ref-doc/TerrainProvider.html) API.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether terrain is shown. When disabled, the globe is a smooth ellipsoid without tiles.
        Enabled (1,1) logical = false

        % built-in provider preset. "cesium-world" uses the public Cesium World Terrain endpoint; "custom" expects a quantized-mesh url in #ic.globe.Terrain.Url
        Provider (1,1) string {mustBeMember(Provider, [ ...
            "cesium-world", "custom"])} = "cesium-world"

        % custom quantized-mesh server url. Used only when #ic.globe.Terrain.Provider is "custom"
        Url (1,1) string = ""

        % vertical scale multiplier applied to all elevations
        Exaggeration (1,1) double {mustBePositive} = 1.0

        % reference height in meters that #ic.globe.Terrain.Exaggeration scales around (0 = sea level)
        ExaggerationRelativeHeight (1,1) double = 0
    end

    events (Description = "Reactive")
        % fires once the initial terrain tiles have loaded and the surface is visible.
        % {payload}
        % provider | string: the provider preset that finished loading
        % {/payload}
        Loaded

        % fires when the terrain provider fails to initialize or a tile fetch errors out.
        % {payload}
        % message | string: human-readable error description
        % {/payload}
        Error
    end

    methods (Access = ?ic.Globe)
        function this = Terrain(props)
            arguments
                props.?ic.globe.Terrain
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end
