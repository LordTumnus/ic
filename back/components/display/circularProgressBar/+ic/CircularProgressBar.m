classdef CircularProgressBar < ic.core.Component
    % > CIRCULARPROGRESSBAR Circular (ring) progress indicator with determinate and indeterminate modes.
    %
    % Displays progress as a circular arc that fills clockwise from the top.
    % Supports determinate (known progress) and indeterminate (spinner) modes,
    % optional gradient coloring, tick marks, and a center label.
    %
    % Example:
    %   cpb = ic.CircularProgressBar();
    %   cpb.Value = 75;           % 75% complete
    %   cpb.ShowLabel = true;     % display "75%" in center
    %
    %   % Indeterminate spinner
    %   cpb.Indeterminate = true;
    %
    %   % Gradient from red to green
    %   cpb.Variant = "gradient";
    %   cpb.Gradient = struct('color', {'#ef4444', '#f59e0b', '#22c55e'}, ...
    %                         'stop',  {0, 50, 100});
    %
    %   % Custom label format
    %   cpb.LabelFormat = "%.1f%%";  % "75.0%"
    %   cpb.LabelFormat = "%d°";     % "75°"
    %
    %   % Gauge-style partial arc (240° from -30° to 210°)
    %   cpb.StartAngle = -30;
    %   cpb.SweepAngle = 240;
    %   cpb.LineCap = "round";
    %
    %   % Instrument-style with tick marks
    %   cpb.ShowTicks = true;
    %   cpb.TickCount = 12;

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current value (between Min and Max)
        Value double = 0
        % > MIN minimum value of the range (0% fill)
        Min double = 0
        % > MAX maximum value of the range (100% fill)
        Max double = 100
        % > INDETERMINATE whether progress is indeterminate (spinner mode)
        Indeterminate logical = false
        % > SIZE overall diameter of the circular progress bar
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT color variant of the progress arc
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive", "gradient"])} = "primary"
        % > GRADIENT color stops for gradient variant (struct array with 'color' and 'stop' fields)
        Gradient struct = struct('color', {'#ef4444', '#f59e0b', '#22c55e'}, 'stop', {0, 50, 100})
        % > SHOWLABEL whether to display progress value in the center
        ShowLabel logical = false
        % > LABELFORMAT sprintf-style format for the center label
        %   Supports %d (integer), %f (float), %.Nf (N decimals), %% (literal %)
        LabelFormat string = "%d%%"
        % > STROKEWIDTH thickness of the progress arc (SVG units)
        StrokeWidth double {mustBePositive(StrokeWidth)} = 4
        % > LINECAP shape of the arc endpoints
        LineCap string {mustBeMember(LineCap, ["butt", "round", "square"])} = "butt"
        % > SHOWTICKS whether to show graduation tick marks around the ring
        ShowTicks logical = false
        % > TICKCOUNT number of tick marks around the ring (max 60)
        TickCount double {mustBePositive(TickCount), mustBeInteger(TickCount)} = 12
        % > STARTANGLE where the arc begins (degrees, clockwise from top, 0 = 12 o'clock)
        StartAngle double = 0
        % > SWEEPANGLE how many degrees the arc spans (1 to 360)
        SweepAngle double {mustBeInRange(SweepAngle, 1, 360)} = 360
    end

    methods
        function this = CircularProgressBar(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end

        function this = styleTrack(this, varargin)
            % > STYLETRACK apply CSS styles to the track ring (background circle)
            %
            % Example:
            %   cpb.styleTrack("stroke", "#e5e7eb");
            this.style(".ic-circular-progress__track", varargin{:});
        end

        function this = styleBar(this, varargin)
            % > STYLEBAR apply CSS styles to the progress arc (filled portion)
            %
            % Example:
            %   cpb.styleBar("stroke", "#3b82f6");
            this.style(".ic-circular-progress__bar", varargin{:});
        end

        function this = styleLabel(this, varargin)
            % > STYLELABEL apply CSS styles to the center label
            %
            % Example:
            %   cpb.styleLabel("color", "#333", "fontWeight", "bold");
            this.style(".ic-circular-progress__label", varargin{:});
        end
    end
end
