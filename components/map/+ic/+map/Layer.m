classdef (Abstract) Layer < ic.core.Component
    % abstract base for all Leaflet map layers.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether this layer is visible
        Visible (1,1) logical = true

        % layer opacity (0 to 1)
        Opacity (1,1) double = 1.0
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % insertion order within the parent map
        LayerIndex (1,1) double = 0
    end

    methods
        function this = Layer(props)
            this@ic.core.Component(props);
        end
    end
end
