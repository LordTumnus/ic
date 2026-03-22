classdef Spinner < ic.core.Component
    % > SPINNER Animated loading indicator with multiple style variants.
    %
    % The Spinner component displays an animated loading indicator. It
    % supports 9 visual styles, 3 sizes, 5 color variants, and 3 speed
    % settings.
    %
    % Example:
    %   s = ic.Spinner();
    %   s.Kind = "bars";        % iOS-style radial bars
    %   s.Size = "lg";          % Large size
    %   s.Variant = "success";  % Green color
    %   s.Speed = "fast";       % Faster animation

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > KIND animation style of the spinner
        Kind string {mustBeMember(Kind, ...
            ["bars", "dots-wave", "dots-line", "ring", ...
             "pulse", "orbit", "grid", "dual-ring", "cube"])} = "ring"
        % > SIZE overall size of the spinner
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT color variant of the spinner
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive"])} = "primary"
        % > SPEED animation speed
        Speed string {mustBeMember(Speed, ...
            ["slow", "normal", "fast"])} = "normal"
    end

    methods
        function this = Spinner(props)
            arguments
                props.?ic.Spinner
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end
