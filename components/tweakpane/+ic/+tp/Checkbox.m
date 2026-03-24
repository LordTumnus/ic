classdef Checkbox < ic.tp.Blade
    % boolean toggle blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % checked state
        Value (1,1) logical = false
    end

    events (Description = "Reactive")
        % fires when the user toggles the checkbox
        % {payload}
        % value | logical: new checked state
        % {/payload}
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
