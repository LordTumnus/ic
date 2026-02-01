classdef Button < ic.core.ComponentContainer
    % > BUTTON Interactive button with optional icon.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text label of the button
        Label string = "Click me"
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"
        % > FILL fill style of the button
        Fill string {mustBeMember(Fill, ...
            ["solid", "outline", "ghost"])} = "solid"
        % > SHAPE shape style of the button
        Shape string {mustBeMember(Shape, ...
            ["default", "pill", "square"])} = "default"
        % > SIZE size of the button -> affects padding
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the button is disabled
        Disabled logical = false
        % > ICONPOSITION position of the icon relative to the label
        IconPosition string {mustBeMember(IconPosition, ...
            ["left", "right"])} = "left"
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
                this.addChild(icon, "icon");
            end
        end

        function validateTarget(this, target)
            % > VALIDATETARGET checks that an icon is the selected target
            assert(target == "icon", "ic:Icon:invalidTarget", ...
                "Buttons only support children in an 'icon' target");
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the button
            out = this.publish("focus", []);
        end
    end
end
