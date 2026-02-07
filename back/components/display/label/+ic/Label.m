classdef Label < ic.core.Component
    % > LABEL Display text with configurable typography.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > TEXT the text content to display
        Text string = ""
        % > VARIANT typography variant
        Variant string {mustBeMember(Variant, ...
            ["body", "heading", "caption", "code", "overline"])} = "body"
        % > SIZE text size
        Size string {mustBeMember(Size, ...
            ["xs", "sm", "md", "lg", "xl", "2xl", "3xl"])} = "md"
        % > WEIGHT font weight
        Weight string {mustBeMember(Weight, ...
            ["normal", "medium", "semibold", "bold"])} = "normal"
        % > ALIGN text alignment
        Align string {mustBeMember(Align, ...
            ["left", "center", "right"])} = "left"
        % > COLOR semantic color variant
        Color string {mustBeMember(Color, ...
            ["default", "muted", "primary", "destructive", "success", "warning"])} = "default"
        % > TRUNCATE whether to truncate overflowing text with ellipsis
        Truncate logical = false
        % > SELECTABLE whether the text can be selected and copied
        Selectable logical = true
    end

    methods
        function this = Label(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end
    end
end
