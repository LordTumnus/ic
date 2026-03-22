classdef Textarea < ic.tp.Blade
    % > TEXTAREA Multi-line text input blade for TweakPane (plugin-textarea).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current text value (may contain newlines)
        Value (1,1) string = ""
        % > ROWS number of visible text rows
        Rows (1,1) double = 3
        % > PLACEHOLDER helper text shown when empty
        Placeholder (1,1) string = ""
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires on each text change
        ValueChanged
    end

    methods
        function this = Textarea(props)
            arguments
                props.?ic.tp.Textarea
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
