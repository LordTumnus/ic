classdef (Abstract) Layer < ic.core.Component
    % abstract base for all CesiumJS globe layers (imagery, terrain, 3D tiles, models).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether this layer is visible
        Visible (1,1) logical = true

        % display name; used by future LayersControl-style UIs
        Name (1,1) string = ""
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % insertion order within the parent #ic.Globe
        LayerIndex (1,1) double = 0
    end

    methods
        function this = Layer(props)
            this@ic.core.Component(props);
        end
    end
end
