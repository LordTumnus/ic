classdef Checkbox < ic.tp.Blade
    % > CHECKBOX Boolean toggle blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE boolean state
        Value (1,1) logical = false
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the user toggles the checkbox
        ValueChanged
    end

    methods
        function this = Checkbox(props)
            arguments
                props.?ic.tp.Checkbox
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
