classdef Slider < ic.tp.Blade
    % numeric slider blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current numeric value
        Value (1,1) double = 0

        % minimum value
        Min (1,1) double = 0

        % maximum value
        Max (1,1) double = 100

        % step increment
        Step (1,1) double = 1
    end

    events (Description = "Reactive")
        % fires continuously during slider drag
        % {payload}
        % value | double: current value
        % {/payload}
        ValueChanging

        % fires when drag ends or value commits
        % {payload}
        % value | double: committed value
        % {/payload}
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
