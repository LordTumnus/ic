classdef ProgressBar < ic.core.Component
    % > PROGRESSBAR Linear progress indicator with determinate and indeterminate modes.
    %
    % The ProgressBar component displays progress as a bar that fills from
    % left to right (horizontal) or bottom to top (vertical). It supports both
    % determinate (known progress) and indeterminate (unknown duration) modes,
    % with optional striped patterns.
    %
    % Example:
    %   pb = ic.ProgressBar();
    %   pb.Value = 50;  % 50% complete
    %
    %   % Indeterminate mode for unknown duration tasks
    %   pb.Indeterminate = true;
    %
    %   % Striped with animation
    %   pb.Striped = true;
    %   pb.Animated = true;
    %
    %   % Custom styling
    %   pb.styleTrack("backgroundColor", "#e0e0e0");
    %   pb.styleBar("backgroundColor", "#4caf50");

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current progress percentage (0 to 100)
        Value double {mustBeInRange(Value, 0, 100)} = 0
        % > INDETERMINATE whether progress is indeterminate (unknown duration)
        Indeterminate logical = false
        % > STRIPED whether to show diagonal stripes pattern
        Striped logical = false
        % > ANIMATED whether stripes should animate (only applies when Striped=true)
        Animated logical = false
        % > SIZE height size of the progress bar
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT color variant of the progress bar
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive", "gradient"])} = "primary"
        % > GRADIENT color stops for gradient variant (struct array with 'color' and 'stop' fields)
        Gradient struct = struct('color', {'#ef4444', '#f59e0b', '#22c55e'}, 'stop', {0, 50, 100})
        % > SHOWLABEL whether to display progress percentage
        ShowLabel logical = false
        % > LABELFORMAT sprintf-style format for the label
        %   Supports %d (integer), %f (float), %.Nf (N decimals), %% (literal %)
        LabelFormat string = "%d%%"
        % > LABELPOSITION position of the label relative to the progress bar
        LabelPosition string {mustBeMember(LabelPosition, ["left", "right"])} = "right"
        % > ORIENTATION layout direction of the progress bar
        Orientation string {mustBeMember(Orientation, ...
            ["horizontal", "vertical"])} = "horizontal"
    end

    methods
        function this = ProgressBar(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end

        function this = styleTrack(this, varargin)
            % > STYLETRACK apply CSS styles to the progress track (background)
            %
            % Example:
            %   pb.styleTrack("backgroundColor", "#e5e7eb");
            %   pb.styleTrack("borderRadius", "4px");
            this.style(".ic-progress__track", varargin{:});
        end

        function this = styleBar(this, varargin)
            % > STYLEBAR apply CSS styles to the progress bar (filled portion)
            %
            % Example:
            %   pb.styleBar("backgroundColor", "#3b82f6");
            %   pb.styleBar("borderRadius", "4px");
            this.style(".ic-progress__bar", varargin{:});
        end
    end
end
