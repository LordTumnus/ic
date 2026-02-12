classdef Knob < ic.core.Component
    % > KNOB Rotary knob input control.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current value of the knob
        Value double = 0
        % > MIN minimum value
        Min double = 0
        % > MAX maximum value
        Max double = 100
        % > STEP step increment
        Step double = 1
        % > DISABLED whether the knob is disabled
        Disabled logical = false
        % > SIZE size of the knob (sm, md, lg)
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT color variant of the knob
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive"])} = "primary"
        % > SHOWVALUE whether to display the current value label
        ShowValue logical = false
        % > SHOWTRACK whether to display the value arc ring
        ShowTrack logical = true
        % > SHOWTICKS whether to display graduation tick marks
        ShowTicks logical = false
        % > TICKCOUNT number of tick marks to display
        TickCount double {mustBePositive(TickCount), mustBeInteger(TickCount)} = 12
        % > LABELFORMAT printf-style format string for the value label
        LabelFormat string = "%d"
        % > LABELPOSITION position of the value label (inside or bottom)
        LabelPosition string {mustBeMember(LabelPosition, ["inside", "bottom"])} = "bottom"
    end

    events (Description = "Reactive")
        % > VALUECHANGING fires continuously during drag with current value
        ValueChanging
        % > VALUECHANGED fires on drag-end or keyboard step with final value
        ValueChanged
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
            % > FOCUS programmatically focus the knob
            out = this.publish("focus", []);
        end
    end
end
