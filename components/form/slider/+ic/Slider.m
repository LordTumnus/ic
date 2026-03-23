classdef Slider < ic.core.Component
    % numeric slider input control

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current value of the slider
        Value double = 0

        % minimum value achieved when the thumb is at the leftmost (or bottommost) position
        Min double = 0

        % maximum value achieved when the thumb is at the rightmost (or topmost) position
        Max double = 100

        % step increment for snapping the thumb
        Step double = 1

        % whether the slider is disabled and cannot be interacted with
        Disabled logical = false

        % layout direction of the slider
        Orientation string {mustBeMember(Orientation, ...
            ["horizontal", "vertical"])} = "horizontal"

        % whether to display a text label with the current value of the slider thumb
        ShowValue logical = false

        % position of the value label relative to the slider (if #ic.Slider.ShowValue is true)
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["top", "bottom", "left", "right"])} = "top"

        % dimension of the slider track and thumb relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % color variant of the slider
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive"])} = "primary"

        % style of the slider thumb
        Thumb string {mustBeMember(Thumb, ...
            ["fader", "circle", "square"])} = "fader"

        % whether to display graduation tick marks along the slider track
        ShowTicks logical = false

        % spacing between tick marks. If the interval is 0, tick marks automatically align with the step increments.
        TickInterval double {mustBeNonnegative(TickInterval)} = 0
    end

    events (Description = "Reactive")
        % triggered continuously while the user interacts with the slider (drag or keyboard)
        % {payload}
        % value | double: current slider value
        % {/payload}
        ValueChanging
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
            % programmatically focus the slider thumb
            out = this.publish("focus", []);
        end
    end
end
