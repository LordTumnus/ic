classdef Slider < ic.tp.Blade
    % > SLIDER Numeric slider blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current numeric value
        Value (1,1) double = 0
        % > MIN minimum value
        Min (1,1) double = 0
        % > MAX maximum value
        Max (1,1) double = 100
        % > STEP step increment
        Step (1,1) double = 1
    end

    events (Description = "Reactive")
        % > VALUECHANGING fires during slider drag
        ValueChanging
        % > VALUECHANGED fires when drag ends or value commits
        ValueChanged
    end

    methods
        function this = Slider(props)
            arguments
                props.?ic.tp.Slider
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
