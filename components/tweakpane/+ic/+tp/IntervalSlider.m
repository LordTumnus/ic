classdef IntervalSlider < ic.tp.Blade
    % dual-handle range slider blade for TweakPane.
    % uses [@tweakpane/plugin-essentials](https://github.com/tweakpane/plugin-essentials).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % selected range as a struct with fields min and max
        Value (1,1) struct = struct('min', 0, 'max', 100)

        % absolute minimum of the range
        Min (1,1) double = 0

        % absolute maximum of the range
        Max (1,1) double = 100
    end

    events (Description = "Reactive")
        % fires when the range changes
        % {payload}
        % value | struct: selected range — value.min and value.max as doubles
        % {/payload}
        ValueChanged
    end

    methods
        function this = IntervalSlider(props)
            arguments
                props.?ic.tp.IntervalSlider
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
