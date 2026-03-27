classdef ProgressBar < ic.core.Component
    % linear progress indicator to indicate the completion

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current value of the progress, clipped to the range defined by Min and Max
        Value double = 0

        % minimum value of the range, representing 0% fill of the progress bar
        Min double = 0

        % maximum value of the range, representing 100% fill of the progress bar
        Max double = 100

        % whether progress is indeterminate (unknown value). If true, shows an infinite loading animation instead of a finite progress
        Indeterminate logical = false

        % whether to show diagonal stripes pattern in the progress bar
        Striped logical = false

        % whether stripes should animate (only applies when #ic.ProgressBar.Striped is set to true)
        Animated logical = false

        % height size of the progress bar, relative to the font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % color scheme of the progress bar
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive", "gradient"])} = "primary"

        % color gradient stops for progressbar, specified as a struct array with fields: color (CSS color string) and stop (numeric percentage). Only applies when #ic.ProgressBar.Variant is set to "gradient"
        Gradient struct = struct('color', {'#ef4444', '#f59e0b', '#22c55e'}, 'stop', {0, 50, 100})

        % whether to display a label with the progress.
        % {note} Label formatting and position can be customized with the #ic.ProgressBar.LabelFormat and #ic.ProgressBar.LabelPosition properties {/note}
        ShowLabel logical = false

        % sprintf-style format for the label.
        % {note} Supports %d (integer), %f (float), %.Nf (N decimals), %% (literal %) {/note}
        LabelFormat string = "%d%%"

        % position of the label relative to the progress bar.
        % {note} When the #ic.ProgressBar.Orientation is set to "vertical", the value of the position will be mapped such that "left" is "top" and "right" is "bottom" {/note}
        LabelPosition string {mustBeMember(LabelPosition, ["left", "right"])} = "right"

        % layout direction of the progress bar
        Orientation string {mustBeMember(Orientation, ...
            ["horizontal", "vertical"])} = "horizontal"
    end

    methods
        function this = ProgressBar(props)
            arguments
                props.?ic.ProgressBar
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end

        function this = styleTrack(this, varargin)
            % convenience method to apply CSS styles directly to the progress track (background portion). See #ic.mixin.Styleable for more details on how to specify styles.
            % {example}
            %   pb.styleTrack("backgroundColor", "#e5e7eb");
            % {/example}
            this.css.style(".ic-progress__track", varargin{:});
        end

        function this = styleBar(this, varargin)
            % convenience method to apply CSS styles directly to the progress bar (filled portion). See #ic.mixin.Styleable for more details on how to specify styles.
            % {example}
            %   pb.styleBar("backgroundColor", "linear-gradient(to right, #ef4444, #f59e0b, #22c55e)");
            % {/example}
            this.css.style(".ic-progress__bar", varargin{:});
        end
    end
end
