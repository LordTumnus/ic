classdef RadioButton < ic.core.ComponentContainer
    % > RADIOBUTTON Single-select radio group with optional per-item icons.
    %
    % Create a radio group:
    %   rb = ic.RadioButton();
    %   rb.Items = ["Option A", "Option B", "Option C"];
    %   rb.Value = "Option A";
    %
    % Horizontal layout:
    %   rb.Orientation = "horizontal";
    %
    % With icons per item:
    %   rb.setIcon("Option A", ic.Icon.fromName("star"));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS labels for each radio option
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]
        % > VALUE currently selected item (scalar)
        Value (1,1) string = "Option 1"
        % > LABEL optional group label displayed above the options
        Label string = ""
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"
        % > SIZE size of the radio buttons
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > LABELPOSITION position of the label relative to the circle
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["right", "left"])} = "right"
        % > ORIENTATION layout direction of the radio group
        Orientation string {mustBeMember(Orientation, ...
            ["vertical", "horizontal"])} = "vertical"
    end

    events (Description = "Reactive")
        Changed
    end

    methods
        function this = RadioButton(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(id);
            this.Targets = this.Items;
        end

        function set.Items(this, val)
            % Delete icons in targets that are being removed
            removed = setdiff(this.Items, val);
            for child = this.Children
                if ismember(child.Target, removed)
                    delete(child);
                end
            end
            this.Items = val;
            this.Targets = val;
        end

        function set.Value(this, val)
            % Value must be scalar for radio buttons
            assert(isscalar(val), "ic:RadioButton:ScalarRequired", ...
                "Value must be a scalar string for RadioButton.");
            this.Value = val;
        end

        function setIcon(this, item, icon)
            % > SETICON Set or replace the icon for a radio item.
            %   rb.setIcon("Option A", ic.Icon.fromName("star"))
            %   rb.setIcon("Option A", [])  % removes the icon
            arguments
                this
                item (1,1) string
                icon
            end
            assert(ismember(item, this.Items), "ic:RadioButton:InvalidItem", ...
                "Item '%s' not found. Items: %s.", item, strjoin(this.Items, ", "));

            % Remove existing icon in this slot
            for child = this.Children
                if child.Target == item
                    delete(child);
                end
            end

            % Add new icon if provided
            if ~isempty(icon)
                this.addChild(icon, item);
            end
        end

        function icon = getIcon(this, item)
            % > GETICON Get the icon for a radio item, or [] if none.
            arguments
                this
                item (1,1) string
            end
            for child = this.Children
                if child.Target == item
                    icon = child;
                    return;
                end
            end
            icon = [];
        end

        function validateChild(this, child, target)
            % > VALIDATECHILD ensures only ic.Icon children in item-named targets
            assert(isa(child, "ic.Icon"), "ic:RadioButton:InvalidChild", ...
                "RadioButton only accepts ic.Icon children.");
            assert(ismember(target, this.Items), "ic:RadioButton:InvalidTarget", ...
                "Target '%s' must match one of the Items: %s.", ...
                target, strjoin(this.Items, ", "));
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the radio group
            out = this.publish("focus", []);
        end
    end
end
