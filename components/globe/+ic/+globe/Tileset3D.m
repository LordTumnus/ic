classdef Tileset3D < ic.globe.Layer
    % Streaming 3D Tiles dataset (photogrammetry, buildings, point clouds). Mirrors the [CesiumJS Cesium3DTileset](https://cesium.com/learn/cesiumjs/ref-doc/Cesium3DTileset.html) API.
    %
    % A tileset is a hierarchy of `.b3dm` / `.i3dm` / `.pnts` / `.glb` chunks streamed on-demand as the camera moves. Use a self-hosted `tileset.json` URL or an Ion asset id. Every network fetch (tileset.json root, child tiles, sub-tile content) is proxied through MATLAB via the `tileset3d` BinaryChannel.
    %
    % Common Ion asset ids:
    %   96188   - Cesium OSM Buildings (worldwide 3D building extrusions)
    %   2275207 - Google Photorealistic 3D Tiles (requires separate agreement)
    %   75343   - Cesium Moon Terrain

    properties (SetObservable, AbortSet, Description = "Reactive")
        % direct tileset URL. Mutually exclusive with #ic.globe.Tileset3D.IonAssetId; if both are set the Ion path wins.
        Url (1,1) string = ""

        % Cesium Ion asset id. Resolved via #ic.Globe.IonToken through MATLAB-side handshake.
        IonAssetId (1,1) double = 0

        % Level of detail quality. Lower = sharper geometry, more bandwidth. Default 16.
        MaximumScreenSpaceError (1,1) double {mustBePositive} = 16

        % optional tileset placement override in degrees
        Position (1,2) double = [NaN NaN]

        % altitude offset in meters. Applied only when #ic.globe.Tileset3D.Position is set.
        Altitude (1,1) double = 0

        % heading in degrees (0 = north). Applied only when #ic.globe.Tileset3D.Position is set.
        Heading (1,1) double = 0

        % pitch in degrees. Applied only when #ic.globe.Tileset3D.Position is set.
        Pitch (1,1) double = 0

        % roll in degrees. Applied only when #ic.globe.Tileset3D.Position is set.
        Roll (1,1) double = 0

        % uniform scale. Applied only when #ic.globe.Tileset3D.Position is set.
        Scale (1,1) double {mustBePositive} = 1.0

        % optional RGBA tint
        Color (1,:) double = []

        % blend strength for #ic.globe.Tileset3D.Color. 0 = no tint, 1 = full replacement.
        ColorBlendAmount (1,1) double {mustBeInRange(ColorBlendAmount, 0, 1)} = 0.5

        % declarative Cesium3DTileStyle. Pass a struct with expression strings, e.g. struct('color', 'color("red")', 'show', '${height} > 20')
        Style (1,1) struct = struct()
    end

    events (Description = "Reactive")
        % fires after the initial root tile has streamed and the tileset becomes visible.
        % {payload}
        % boundingSphere | 1x4 double: [x,y,z,radius] of the tileset bounds in ECEF
        % {/payload}
        Loaded

        % fires when all tiles in the current view are loaded (no pending streaming).
        AllTilesLoaded

        % fires on fetch or decode failures.
        % {payload}
        % message | string: human-readable error description
        % {/payload}
        Error
    end

    methods
        function this = Tileset3D(props)
            arguments
                props.?ic.globe.Tileset3D
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.globe.Layer(props);
        end
    end
end
