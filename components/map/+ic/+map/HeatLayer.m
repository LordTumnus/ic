classdef HeatLayer < ic.map.Layer
    % heatmap visualization layer rendered from point data with intensity.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % heat data as Nx2 [lat,lng] or Nx3 [lat,lng,intensity]
        Data (:,:) double = zeros(0, 3)

        % point radius in pixels
        Radius (1,1) double = 25

        % maximum intensity for color normalization (0 = auto)
        MaxIntensity (1,1) double = 0

        % minimum opacity of the heat layer
        MinOpacity (1,1) double = 0.05

        % blur size in pixels
        Blur (1,1) double = 15

        % gradient stop positions (values between 0 and 1)
        GradientPositions (1,:) double = [0.4, 0.65, 1]

        % colors corresponding to each gradient position
        GradientColors (1,:) string = ["blue", "lime", "red"]
    end

    methods
        function this = HeatLayer(props)
            arguments
                props.?ic.map.HeatLayer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end
    end
end
