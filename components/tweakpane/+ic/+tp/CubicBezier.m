classdef CubicBezier < ic.tp.Blade
    % cubic bezier curve editor blade for TweakPane.
    % uses [@tweakpane/plugin-essentials](https://github.com/tweakpane/plugin-essentials).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % bezier control points as a struct with fields x1, y1, x2, y2
        Value (1,1) struct = struct('x1', 0, 'y1', 0, 'x2', 1, 'y2', 1)
    end

    events (Description = "Reactive")
        % fires when the curve changes
        % {payload}
        % value | struct: control points — value.x1, value.y1, value.x2, value.y2 as doubles
        % {/payload}
        ValueChanged
    end

    methods
        function this = CubicBezier(props)
            arguments
                props.?ic.tp.CubicBezier
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
