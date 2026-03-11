classdef Wheel < ic.tp.Blade
    % > WHEEL Jog wheel blade for TweakPane (plugin-camerakit).
    %
    % A scroll-wheel control for fine-grained unbounded adjustment.
    % Think jog wheel on a mixing console or frequency tuner.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current numeric value
        Value (1,1) double = 0
        % > AMOUNT value change per pixel of movement (sensitivity)
        Amount (1,1) double = 1
    end

    events (Description = "Reactive")
        % > VALUECHANGING fires during wheel interaction
        ValueChanging
        % > VALUECHANGED fires when interaction ends
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
