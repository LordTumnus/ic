classdef Textarea < ic.tp.Blade
    % multi-line text input blade for TweakPane.
    % uses [@pangenerator/tweakpane-textarea-plugin](https://github.com/pangenerator/tweakpane-textarea-plugin).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current text value (may contain newlines)
        Value (1,1) string = ""

        % number of visible text rows
        Rows (1,1) double = 3

        % ghost text shown when the field is empty
        Placeholder (1,1) string = ""
    end

    events (Description = "Reactive")
        % fires on each text change
        % {payload}
        % value | char: current text content
        % {/payload}
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
