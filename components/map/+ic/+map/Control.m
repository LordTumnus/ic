classdef (Abstract) Control < ic.core.Component
    % abstract base for all Leaflet map controls.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % corner position of the control
        Position (1,1) string {mustBeMember(Position, ...
            ["topleft", "topright", "bottomleft", "bottomright"])} = "topright"
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % insertion order within the parent map
        LayerIndex (1,1) double = 0
    end

    methods
        function this = Control(props)
            this@ic.core.Component(props);
        end
    end
end
