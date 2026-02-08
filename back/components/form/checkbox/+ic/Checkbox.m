classdef Checkbox < ic.core.ComponentContainer
    % > CHECKBOX Toggle checkbox with optional custom icon.
    %
    % Create checkboxes:
    %   cb = ic.Checkbox();
    %   cb.Label = "Accept terms";
    %   cb.Value = "on";
    %
    % With a custom icon (replaces default checkmark):
    %   cb = ic.Checkbox();
    %   cb.Icon = ic.Icon.fromName("star");
    %
    % Indeterminate state:
    %   cb.Indeterminate = true;

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE checkbox state (on or off)
        Value matlab.lang.OnOffSwitchState = "off"
        % > LABEL text label displayed next to the checkbox
        Label string = ""
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"
        % > SIZE size of the checkbox
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the checkbox is disabled
        Disabled logical = false
        % > INDETERMINATE whether the checkbox shows an indeterminate state
        Indeterminate logical = false
        % > LABELPOSITION position of the label relative to the checkbox
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["right", "left"])} = "right"
    end

    properties (Dependent)
        Icon  % Convenient access to the icon child
    end

    events (Description = "Reactive")
        Changed
    end

    methods
        function this = Checkbox(id)
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
            delete(this.Icon);
            if ~isempty(icon)
                this.addChild(icon, "icon");
            end
        end

        function validateChild(this, child, target)
            % > VALIDATECHILD checks target is "icon" and child is ic.Icon
            assert(target == "icon", "ic:Checkbox:InvalidTarget", ...
                "Checkboxes only support children in an 'icon' target");
            assert(isa(child, "ic.Icon"), "ic:Checkbox:InvalidChild", ...
                "Checkbox 'icon' target only accepts ic.Icon components");
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the checkbox
            out = this.publish("focus", []);
        end
    end
end
