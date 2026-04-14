classdef Globe < ic.core.ComponentContainer
    % 3D interactive globe powered by [CesiumJS](https://cesium.com/).
    % Add layers and controls to build a geospatial 3D visualization. Tiles and terrain are fetched through MATLAB's webread and streamed to the frontend via the BinaryChannel mixin.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % css height of the globe container
        Height (1,1) string = "400px"

        % scene mode -- "3D" for a globe, "2D" for a top-down map, "Columbus" for 2.5D
        SceneMode string {mustBeMember(SceneMode, ["3D", "2D", "Columbus"])} = "3D"

        % whether the sky atmosphere (blue halo around the globe) is rendered
        EnableAtmosphere (1,1) logical = true
    end

    methods
        function this = Globe(props)
            arguments
                props.?ic.Globe
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end
