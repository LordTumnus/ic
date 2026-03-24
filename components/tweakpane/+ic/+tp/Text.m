classdef Text < ic.tp.Blade
    % string input blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current text value
        Value (1,1) string = ""
    end

    events (Description = "Reactive")
        % fires on each keystroke
        % {payload}
        % value | char: current text
        % {/payload}
        ValueChanged
        % fires when Enter is pressed
        % {payload}
        % value | char: submitted text
        % {/payload}
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
