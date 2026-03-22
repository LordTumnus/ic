classdef Ring < ic.tp.Blade
    % > RING Radial dial blade for TweakPane (plugin-camerakit).
    %
    % Displays a circular ring control with tick marks and scale.
    % Ideal for angle, phase, or compass heading inputs.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current numeric value
        Value (1,1) double = 0
        % > MIN minimum value
        Min (1,1) double = 0
        % > MAX maximum value
        Max (1,1) double = 360
        % > STEP step increment
        Step (1,1) double = 1
        % > WIDE hide text input and widen the ring display
        Wide (1,1) logical = false
        % > SERIES visual style variant (0, 1, or 2)
        Series (1,1) double {mustBeMember(Series, [0 1 2])} = 0
    end

    events (Description = "Reactive")
        % > VALUECHANGING fires during drag
        ValueChanging
        % > VALUECHANGED fires when drag ends or value commits
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
