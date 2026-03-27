classdef CircularProgressBar < ic.core.Component
    % circular progress indicator to indicate progress

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current value of the progress, clipped to the range defined by Min and Max
        Value double = 0

        % minimum value of the range, representing 0% fill of the progress bar
        Min double = 0

        % maximum value of the range, representing 100% fill of the progress bar
        Max double = 100

        % whether progress is indeterminate (unknown value). If true, shows an infinite spinning animation instead of a finite progress
        Indeterminate logical = false

        % overall diameter of the circular progress bar, relative to the font size of the component
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % color variant of the progress arc
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive", "gradient"])} = "primary"

        % color gradient stops for progress arc, specified as a struct array with fields: color (CSS color string) and stop (numeric percentage). Only applies when #ic.CircularProgressBar.Variant is set to "gradient"
        Gradient struct = struct('color', {'#ef4444', '#f59e0b', '#22c55e'}, 'stop', {0, 50, 100})

        % whether to display the progress value as a label in the center of the circle
        % {note} Label formatting can be customized with the #ic.CircularProgressBar.LabelFormat property {/note}
        ShowLabel logical = false

        % sprintf-style format for the label
        % {note} Supports %d (integer), %f (float), %.Nf (N decimals), %% (literal %) {/note}
        LabelFormat string = "%d%%"

        % thickness of the progress arc, in SVG units (the viewBox of the circular progress is 100x100, so a StrokeWidth of 10 means the arc thickness is 10% of the diameter)
        StrokeWidth double {mustBePositive(StrokeWidth)} = 4

        % shape of the arc endpoints
        LineCap string {mustBeMember(LineCap, ["butt", "round", "square"])} = "butt"

        % whether to show graduation tick marks around the ring
        % {note} Tick marks will be evenly spaced along the circumference of the circle, and the number of ticks can be configured with the #ic.CircularProgressBar.TickCount property {/note}
        ShowTicks logical = false

        % number of tick marks around the ring
        TickCount double {mustBePositive(TickCount), mustBeInteger(TickCount), mustBeLessThanOrEqual(TickCount, 60)} = 12

        % angle at which the arc begins, in degrees. The angle is measured clockwise from top (i.e. 0 degrees means the arc starts at 12 o'clock)
        StartAngle double = 0

        % how many degrees the arc spans, in degrees. For example, a SweepAngle of 180 means the arc will span half the circle (e.g. from 12 o'clock to 6 o'clock if #ic.CircularProgressBar.StartAngle is 0)
        SweepAngle double {mustBeInRange(SweepAngle, 1, 360)} = 360
    end

    methods
        function this = CircularProgressBar(props)
            arguments
                props.?ic.CircularProgressBar
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end

        function this = styleTrack(this, varargin)
            % convenience method to apply CSS styles directly to the progress track (background portion). See #ic.mixin.Styleable for more details on how to specify styles.
            this.css.style(".ic-circular-progress__track", varargin{:});
        end

        function this = styleBar(this, varargin)
            % convenience method to apply CSS styles directly to the progress bar (arc portion). See #ic.mixin.Styleable for more details on how to specify styles.
            this.css.style(".ic-circular-progress__bar", varargin{:});
        end

        function this = styleLabel(this, varargin)
            % convenience method to apply CSS styles directly to the label. See #ic.mixin.Styleable for more details on how to specify styles.
            this.css.style(".ic-circular-progress__label", varargin{:});
        end
    end
end
