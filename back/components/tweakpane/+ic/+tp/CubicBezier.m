classdef CubicBezier < ic.tp.Blade
    % > CUBICBEZIER Cubic bezier curve editor (plugin-essentials).
    %
    % Value is a struct with fields {x1, y1, x2, y2}.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE bezier control points: {x1, y1, x2, y2}
        Value (1,1) struct = struct('x1', 0, 'y1', 0, 'x2', 1, 'y2', 1)
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the curve changes
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
