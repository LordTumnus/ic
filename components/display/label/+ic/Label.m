classdef Label < ic.core.Component
    % displays text with configurable typography and styling options

    properties (SetObservable, AbortSet, Description = "Reactive")
        % the text content to display
        Text string = ""

        % semantic variant that determines the default styling of the label
        Variant string {mustBeMember(Variant, ...
            ["body", "heading", "caption", "code", "overline"])} = "body"

        % text size, scaling the base font size of the label (i.e "xs" applies a 0.625 scaling factor to the base font size, "lg" applies a 1 scaling factor, etc.)
        Size string {mustBeMember(Size, ...
            ["xs", "sm", "md", "lg", "xl", "2xl", "3xl"])} = "md"

        % font weight
        Weight string {mustBeMember(Weight, ...
            ["normal", "medium", "semibold", "bold"])} = "normal"

        % text alignment within the label
        Align string {mustBeMember(Align, ...
            ["left", "center", "right"])} = "left"

        % text color specified as a semantic color name
        Color string {mustBeMember(Color, ...
            ["default", "muted", "primary", "destructive", "success", "warning"])} = "default"

        % whether to truncate overflowing text with ellipsis
        Truncate logical = false

        % whether the text can be selected and copied
        Selectable logical = true
    end

    methods
        function this = Label(props)
            arguments
                props.?ic.Label
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end
