classdef Text < ic.tp.Blade
    % > TEXT String input blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current text value
        Value (1,1) string = ""
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires on each text change
        ValueChanged
        % > SUBMITTED fires when Enter is pressed
        Submitted
    end

    methods
        function this = Text(props)
            arguments
                props.?ic.tp.Text
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
