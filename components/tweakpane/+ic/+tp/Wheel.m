classdef Wheel < ic.tp.Blade
    % jog wheel blade for TweakPane, for fine-grained unbounded adjustment.
    % uses [@tweakpane/plugin-camerakit](https://github.com/tweakpane/plugin-camerakit).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current numeric value
        Value (1,1) double = 0

        % value change per pixel of wheel movement
        Amount (1,1) double = 1
    end

    events (Description = "Reactive")
        % fires continuously during wheel interaction
        % {payload}
        % value | double: current value
        % {/payload}
        ValueChanging

        % fires when wheel interaction ends
        % {payload}
        % value | double: committed value
        % {/payload}
        ValueChanged
    end

    methods
        function this = Wheel(props)
            arguments
                props.?ic.tp.Wheel
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
