classdef SplitButton < ic.core.ComponentContainer
    % button with a dropdown for additional actions.
    % Displays a main button with a chevron trigger that opens a dropdown listing all items with optional icons/images and descriptions.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % list of labels for each action. The first item is considered the "main" action and is triggered when the main button (not the chevron) is clicked
        Items (1,:) string = "Action"

        % optional descriptions shown below each item label in the dropdown
        ItemDescriptions (1,:) string = string.empty

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"

        % fill style of the button
        Fill string {mustBeMember(Fill, ...
            ["solid", "outline", "ghost"])} = "solid"

        % dimensions of the button relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the control is disabled and cannot be interacted with
        Disabled logical = false

        % layout of the split button and dropdown chevron
        SplitDirection string {mustBeMember(SplitDirection, ...
            ["right", "bottom"])} = "right"
    end

    properties (Dependent)
        % the icon of the main action button
        MainIcon ic.Icon
    end

    events (Description = "Reactive")
        % triggered when an item is selected (the main button or an item in the dropdown)
        % {payload}
        % index | double: index of the selected item in #ic.SplitButton.Items
        % label | char: label text of the selected item
        % {/payload}
        ItemSelected

        % fires when the dropdown opens
        Opened

        % fires when the dropdown closes
        Closed
    end

    methods
        function this = SplitButton(props)
            arguments
                props.?ic.SplitButton
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = ["icon", this.Items];
        end

        function icon = get.MainIcon(this)
            mask = arrayfun(@(c) c.Target == "icon", this.Children);
            if any(mask)
                icon = this.Children(mask);
            else
                icon = ic.Icon.empty();
            end
        end

        function set.MainIcon(this, icon)
            delete(this.MainIcon);
            if ~isempty(icon)
                this.addChild(icon, "icon");
            end
        end

        function set.Items(this, val)
            removed = setdiff(this.Items, val);
            for child = this.Children
                if ismember(child.Target, removed)
                    delete(child);
                end
            end
            this.Items = val;
            this.Targets = ["icon", val];
        end

        function setIcon(this, item, icon)
            % set, replace or remove the icon for a dropdown item
            % {example}
            % btn = ic.SplitButton("Items", ["New", "Edit", "Delete"]);
            % btn.setIcon("Edit", "star");
            % {/example}
            arguments
                this
                % one of the #ic.SplitButton.Items to set the icon for
                item (1,1) string
                % icon to display for the item, or empty to remove the icon
                icon ic.Icon {mustBeScalarOrEmpty} = ic.Icon.empty()
            end
            assert(ismember(item, this.Items), "ic:SplitButton:InvalidItem", ...
                "Item '%s' not found. Items: %s.", item, strjoin(this.Items, ", "));
            mask = arrayfun(@(child) child.Target == item, this.Children);
            delete(this.Children(mask));
            if ~isempty(icon)
                this.addChild(icon, item);
            end
        end

        function icon = getIcon(this, item)
            % get the icon for a dropdown item
            % {returns} the #ic.Icon object for the item, or empty if there is no icon {/returns}
            arguments
                this
                % one of the #ic.SplitButton.Items to get the icon for
                item (1,1) string
            end
            assert(ismember(item, this.Items), "ic:SplitButton:InvalidItem", ...
                "Item '%s' not found. Items: %s.", item, strjoin(this.Items, ", "));
            for child = this.Children
                if child.Target == item
                    icon = child;
                    return;
                end
            end
            icon = [];
        end
    end
    methods (Hidden)
        function validateChild(this, child, target)
            % ensures children are icons/images in valid targets
            assert(isa(child, "ic.Icon") || isa(child, "ic.Image"), ...
                "ic:SplitButton:InvalidChild", ...
                "SplitButton only accepts ic.Icon or ic.Image children.");
            assert(target == "icon" || ismember(target, this.Items), ...
                "ic:SplitButton:InvalidTarget", ...
                "Target must be 'icon' or one of Items: %s.", ...
                strjoin(this.Items, ", "));
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the main button
            out = this.publish("focus", []);
        end
    end
end
