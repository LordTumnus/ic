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

    properties (Description = "Reactive", SetObservable, Access = ?ic.mixin.Reactive)
        % maps item names to icon component IDs for per-item icon rendering
        IconMap struct = struct()
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
        end

        function icon = get.MainIcon(this)
            % first icon/image child is the main icon
            for child = this.Children
                if isa(child, 'ic.Icon') || isa(child, 'ic.Image')
                    icon = child;
                    return;
                end
            end
            icon = ic.Icon.empty();
        end

        function set.MainIcon(this, icon)
            delete(this.MainIcon);
            if ~isempty(icon)
                this.addChild(icon);
            end
        end

        function set.Items(this, val)
            this.Items = val;
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
            existing = this.getIcon(item);
            if ~isempty(existing), delete(existing); end
            if ~isempty(icon)
                this.addChild(icon);
                this.IconMap.(matlab.lang.makeValidName(item)) = icon.ID;
            else
                if isfield(this.IconMap, matlab.lang.makeValidName(item))
                    this.IconMap = rmfield(this.IconMap, matlab.lang.makeValidName(item));
                end
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
            itemIdx = find(this.Items == item, 1);
            icons = this.Children(arrayfun(@(c) isa(c, 'ic.Icon') || isa(c, 'ic.Image'), this.Children));
            % first icon is MainIcon, item icons start at index 2
            iconIdx = itemIdx + 1;
            if iconIdx <= numel(icons)
                icon = icons(iconIdx);
            else
                icon = [];
            end
        end
    end
    methods (Hidden)
        function validateChild(~, child)
            assert(isa(child, "ic.Icon") || isa(child, "ic.Image"), ...
                "ic:SplitButton:InvalidChild", ...
                "SplitButton only accepts ic.Icon or ic.Image children.");
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the main button
            out = this.publish("focus", []);
        end
    end
end
