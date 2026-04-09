classdef Checkbox < ic.core.ComponentContainer
    % simple toggle checkbox

    properties (SetObservable, AbortSet, Description = "Reactive")
        % checkbox state (on or off)
        Value matlab.lang.OnOffSwitchState = "off"

        % text label displayed next to the checkbox
        Label string = ""

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"

        % dimension of the checkbox relative to the text font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the checkbox is disabled and cannot be interacted with
        Disabled logical = false

        % when true, the checkbox is in an indeterminate state (neither on nor off) and displays a dash instead of a checkmark
        Indeterminate logical = false

        % position of the label relative to the checkbox
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["right", "left"])} = "right"
    end

    properties (Dependent)
        % #ic.Icon displayed when the checkbox is selected (#ic.Checkbox.Value is "on")
        Icon
    end

    events (Description = "Reactive")
        % triggered when the user toggles the checkbox
        % {payload}
        % value | char: current checkbox state ('on' or 'off')
        % {/payload}
        ValueChanged
    end

    methods
        function this = Checkbox(props)
            arguments
                props.?ic.Checkbox
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end

        function icon = get.Icon(this)
            for child = this.Children
                if isa(child, 'ic.Icon')
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
            assert(isa(child, "ic.Icon"), "ic:Checkbox:InvalidChild", ...
                "Checkbox only accepts ic.Icon children.");
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the checkbox
            out = this.publish("focus", []);
        end
    end
end
