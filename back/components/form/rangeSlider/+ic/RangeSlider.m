classdef RangeSlider < ic.core.Component
    % > RANGESLIDER Dual-thumb slider for selecting a numeric range.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LOW lower bound of the selected range
        Low double = 0
        % > HIGH upper bound of the selected range
        High double = 100
        % > MIN minimum value of the track
        Min double = 0
        % > MAX maximum value of the track
        Max double = 100
        % > STEP step increment for snapping
        Step double = 1
        % > DISABLED whether the range slider is disabled
        Disabled logical = false
        % > ORIENTATION layout direction of the slider
        Orientation string {mustBeMember(Orientation, ...
            ["horizontal", "vertical"])} = "horizontal"
        % > SHOWVALUE whether to display the current value labels
        ShowValue logical = false
        % > LABELPOSITION position of the value labels relative to the slider
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["top", "bottom", "side"])} = "top"
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
        LowChanging
        HighChanging
    end

    methods
        function this = RangeSlider(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the low thumb
            out = this.publish("focus", []);
        end
    end
end
