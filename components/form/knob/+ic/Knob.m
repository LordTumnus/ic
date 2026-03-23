classdef Knob < ic.core.Component
    % rotary knob input control.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current value of the knob
        Value double = 0

        % minimum value
        Min double = 0

        % maximum value
        Max double = 100

        % step increment
        Step double = 1

        % whether the knob is disabled and cannot be interacted with
        Disabled logical = false

        % dimension of the knob relative to the text font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % color variant of the knob
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive"])} = "primary"

        % whether to display the current value in text form
        ShowValue logical = false

        % whether to display an arc ring along the knob from the #ic.Knob.Min position to the current value
        ShowTrack logical = true

        % whether to display graduation tick marks. Ticks are evenly spaced between the #ic.Knob.Min and #ic.Knob.Max values, with a total count specified by #ic.Knob.TickCount
        ShowTicks logical = false

        % number of tick marks to display if #ic.Knob.ShowTicks is true
        TickCount double {mustBePositive(TickCount), mustBeInteger(TickCount)} = 12

        % sprintf-style format string for the value label
        LabelFormat string = "%d"

        % position of the value label relative to the knob
        LabelPosition string {mustBeMember(LabelPosition, ["inside", "bottom"])} = "bottom"
    end

    events (Description = "Reactive")
        % triggers continuously while the user interacts with the knob (drag or keyboard)
        % {payload}
        % value | double: current knob value
        % {/payload}
        ValueChanging
    end

    methods
        function this = Knob(props)
            arguments
                props.?ic.Knob
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the knob
            out = this.publish("focus", []);
        end
    end
end
