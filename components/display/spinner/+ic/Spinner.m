classdef Spinner < ic.core.Component
    % animated loading indicator with multiple style variants.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % animation style of the spinner
        Kind string {mustBeMember(Kind, ...
            ["bars", "dots-wave", "dots-line", "ring", ...
             "pulse", "orbit", "grid", "dual-ring", "cube"])} = "ring"

        % overall size of the spinner, relative to the font size of the component
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % color scheme used for the spinner
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "success", "warning", "destructive"])} = "primary"

        % animation speed
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
