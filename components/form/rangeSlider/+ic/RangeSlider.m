classdef RangeSlider < ic.core.Component
    % dual-thumb slider for selecting a numeric range (see also: #ic.Slider)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current lower value of the selected range
        Low double = 0

        % current upper value of the selected range
        High double = 100

        % minimum value of the track
        Min double = 0

        % maximum value of the track
        Max double = 100

        % step increment for snapping the thumbs
        Step double = 1

        % whether the range slider is disabled and cannot be interacted with
        Disabled logical = false

        % layout direction of the slider
        Orientation string {mustBeMember(Orientation, ...
            ["horizontal", "vertical"])} = "horizontal"

        % whether to display a label with the current value(s) of the slider thumbs
        ShowValue logical = false

        % position of the value labels relative to the slider
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["top", "bottom", "side"])} = "top"

        % dimensions of the slider track and thumbs relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % color variant of the slider
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive"])} = "primary"

        % style of the slider thumb
        Thumb string {mustBeMember(Thumb, ...
            ["fader", "circle", "square"])} = "fader"

        % whether to display graduation tick marks along the slider track
        ShowTicks logical = false

        % spacing between tick marks (if 0, they automatically align with the step increments)
        TickInterval double {mustBeNonnegative(TickInterval)} = 0
    end

    events (Description = "Reactive")
        % event triggered when the low thumb value is changing
        % {payload}
        % value | double: current low thumb value
        % {/payload}
        LowChanging

        % event triggered when the high thumb value is changing
        % {payload}
        % value | double: current high thumb value
        % {/payload}
        HighChanging
    end

    methods
        function this = RangeSlider(props)
            arguments
                props.?ic.RangeSlider
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the low thumb
            out = this.publish("focus", []);
        end
    end
end
