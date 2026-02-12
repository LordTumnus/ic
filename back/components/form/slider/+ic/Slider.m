classdef Slider < ic.core.Component
    % > SLIDER Numeric slider input control.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current value of the slider
        Value double = 0
        % > MIN minimum value
        Min double = 0
        % > MAX maximum value
        Max double = 100
        % > STEP step increment
        Step double = 1
        % > DISABLED whether the slider is disabled
        Disabled logical = false
        % > ORIENTATION layout direction of the slider
        Orientation string {mustBeMember(Orientation, ...
            ["horizontal", "vertical"])} = "horizontal"
        % > SHOWVALUE whether to display the current value label
        ShowValue logical = false
        % > LABELPOSITION position of the value label relative to the slider
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["top", "bottom", "left", "right"])} = "top"
        % > SIZE size of the slider track and thumb
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT color variant of the slider
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive"])} = "primary"
        % > THUMB style of the slider thumb
        Thumb string {mustBeMember(Thumb, ...
            ["fader", "circle", "square"])} = "fader"
        % > SHOWTICKS whether to display graduation tick marks
        ShowTicks logical = false
        % > TICKINTERVAL spacing between tick marks (0 = auto from Step)
        TickInterval double {mustBeNonnegative(TickInterval)} = 0
    end

    events (Description = "Reactive")
        % > VALUECHANGING fires continuously during drag with current value
        ValueChanging
        % > VALUECHANGED fires on drag-end or keyboard step with final value
        ValueChanged
    end

    methods
        function this = Slider(props)
            arguments
                props.?ic.Slider
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the slider thumb
            out = this.publish("focus", []);
        end
    end
end
