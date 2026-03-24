classdef Ring < ic.tp.Blade
    % radial dial blade for TweakPane, ideal for angles and headings.
    % uses [@tweakpane/plugin-camerakit](https://github.com/tweakpane/plugin-camerakit).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current numeric value
        Value (1,1) double = 0

        % minimum value
        Min (1,1) double = 0

        % maximum value
        Max (1,1) double = 360

        % step increment
        Step (1,1) double = 1

        % hide the text input and widen the ring display
        Wide (1,1) logical = false

        % visual style variant (0, 1, or 2)
        Series (1,1) double {mustBeMember(Series, [0 1 2])} = 0
    end

    events (Description = "Reactive")
        % fires continuously during drag
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
        function this = Ring(props)
            arguments
                props.?ic.tp.Ring
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
