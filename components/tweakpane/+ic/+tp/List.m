classdef List < ic.tp.Blade
    % dropdown select blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % currently selected item
        Value (1,1) string = ""

        % list of selectable options
        Items (1,:) string = string.empty
    end

    events (Description = "Reactive")
        % fires when the selection changes
        % {payload}
        % value | char: selected item
        % {/payload}
        ValueChanged
    end

    methods
        function this = List(props)
            arguments
                props.?ic.tp.List
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
