classdef Button < ic.core.ComponentContainer
    % interactive button component that can be clicked to trigger actions

    properties (SetObservable, AbortSet, Description = "Reactive")
        % text label of the button
        Label string = "Click me"

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"

        % fill style of the button
        Fill string {mustBeMember(Fill, ...
            ["solid", "outline", "ghost"])} = "solid"

        % shape style of the button
        Shape string {mustBeMember(Shape, ...
            ["default", "pill", "square"])} = "default"

        % dimension of the button, as a function of the text font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the button is disabled and cannot be interacted with
        Disabled logical = false

        % position of the icon relative to the label (see #ic.Button.Icon)
        IconPosition string {mustBeMember(IconPosition, ...
            ["left", "right"])} = "left"
    end

    properties (Dependent)
        % child icon, either an #ic.Icon or #ic.Image
        Icon
    end

    events (Description = "Reactive")
        % event triggered when the button is clicked
        % {payload}
        % timestamp | char: datetime of the click event
        % {/payload}
        Clicked
    end

    methods
        function this = Button(props)
            arguments
                props.?ic.Button
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end

        function icon = get.Icon(this)
            for child = this.Children
                if isa(child, 'ic.Icon') || isa(child, 'ic.Image')
                    icon = child;
                    return;
                end
            end
            icon = [];
        end

        function set.Icon(this, icon)
            delete(this.Icon);
            if ~isempty(icon)
                this.addChild(icon);
            end
        end

    end
    methods (Hidden)
        function validateChild(~, child)
            assert(isa(child, "ic.Icon") || isa(child, "ic.Image"), ...
                "ic:Button:InvalidChild", ...
                "Button only accepts ic.Icon or ic.Image children.");
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the button
            out = this.publish("focus", []);
        end
    end
end
