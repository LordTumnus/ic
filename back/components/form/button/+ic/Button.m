classdef Button < ic.core.ComponentContainer
    % BUTTON Interactive button with optional icon.

    properties (SetObservable, AbortSet, Description = "Reactive")
        Label string = ""
        Variant string {mustBeMember(Variant, ["primary", "secondary", "destructive"])} = "primary"
        Fill string {mustBeMember(Fill, ["solid", "outline", "ghost"])} = "solid"
        Shape string {mustBeMember(Shape, ["default", "pill", "square"])} = "default"
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        Disabled logical = false
        IconPosition string {mustBeMember(IconPosition, ["left", "right"])} = "left"
    end

    properties (Dependent)
        Icon
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
            this.Targets = "icon";
        end

        function icon = get.Icon(this)
            for child = this.Children
                if child.Target == "icon"
                    icon = child;
                    return;
                end
            end
            icon = [];
        end

        function set.Icon(this, icon)
            % Remove existing icon from slot
            delete(this.Icon);
            % Add new icon
            if ~isempty(icon)
                icon.setParent(this, "icon");
            end
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            out = this.publish("focus", []);
        end
    end
end
