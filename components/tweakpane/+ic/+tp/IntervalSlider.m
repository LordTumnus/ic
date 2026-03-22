classdef IntervalSlider < ic.tp.Blade
    % > INTERVALSLIDER Dual-handle range slider (plugin-essentials).
    %
    % Value is a struct with fields 'min' and 'max'.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE range struct: {min, max}
        Value (1,1) struct = struct('min', 0, 'max', 100)
        % > MIN absolute minimum of the range
        Min (1,1) double = 0
        % > MAX absolute maximum of the range
        Max (1,1) double = 100
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the range changes
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
