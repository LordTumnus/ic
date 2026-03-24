classdef Point < ic.tp.Blade
    % 2D/3D/4D point input blade for TweakPane.
    % dimensionality is auto-detected from the struct fields in Value.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % point coordinates: {x,y} for 2D, {x,y,z} for 3D, {x,y,z,w} for 4D
        Value (1,1) struct = struct('x', 0, 'y', 0)
    end

    events (Description = "Reactive")
        % fires when any coordinate changes
        % {payload}
        % value | struct: coordinate struct matching the Value fields (x, y[, z[, w]])
        % {/payload}
        ValueChanged
    end

    methods
        function this = Point(props)
            arguments
                props.?ic.tp.Point
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
