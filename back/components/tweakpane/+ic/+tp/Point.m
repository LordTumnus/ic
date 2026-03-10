classdef Point < ic.tp.Blade
    % > POINT 2D/3D/4D point input blade for TweakPane.
    %
    % Value is a struct with fields x, y (and optionally z, w).
    % Tweakpane auto-detects dimensionality from the struct fields.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE point struct: {x,y} or {x,y,z} or {x,y,z,w}
        Value (1,1) struct = struct('x', 0, 'y', 0)
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the point value changes
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
