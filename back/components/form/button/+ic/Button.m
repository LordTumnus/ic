classdef Button < ic.core.ComponentContainer
    % BUTTON Interactive button with optional icon.

    properties (SetObservable, AbortSet, Description = "Reactive")
        Label string = ""
        Variant string {mustBeMember(Variant, ["primary", "secondary", "destructive"])} = "primary"
        Fill string {mustBeMember(Fill, ["solid", "outline", "ghost"])} = "solid"
        Shape string {mustBeMember(Shape, ["default", "pill", "square"])} = "default"
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        Disabled logical = false
        IconPosition string {mustBeMember(IconPosition, ["", "left", "right"])} = ""
    end

    properties (SetAccess = immutable)
        % Built-in icon (static child)
        Icon ic.Icon
    end

    events (Description = "Reactive")
        Clicked
    end

    methods
        function this = Button(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(id);

            % Create static icon child
            this.Icon = ic.Icon(id + "-icon");
            this.Icon.Size = 16;
            this.addStaticChild(this.Icon);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            out = this.publish("focus", []);
        end
    end
end
