classdef RadioButton < ic.core.ComponentContainer
    % single-select radio group

    properties (SetObservable, AbortSet, Description = "Reactive")
        % labels for each radio option
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]

        % currently selected item
        Value (1,1) string = "Option 1"

        % optional group label displayed above the options
        Label string = ""

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"

        % dimension of the radio buttons relative to the text font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the control is disabled and cannot be interacted with
        Disabled logical = false

        % position of each row label relative to its button
        LabelPosition string {mustBeMember(LabelPosition, ...
            ["right", "left"])} = "right"

        % layout direction of the radio group
        Orientation string {mustBeMember(Orientation, ...
            ["vertical", "horizontal"])} = "vertical"
    end

    properties (Description = "Reactive", SetObservable, Access = ?ic.mixin.Reactive)
        % maps item names to icon component IDs for per-item icon rendering
        IconMap struct = struct()
    end

    events (Description = "Reactive")
        % triggered when the user selects a different option
        % {payload}
        % value | char: label of the newly selected item
        % {/payload}
        ValueChanged
    end

    methods
        function this = RadioButton(props)
            arguments
                props.?ic.RadioButton
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end

        function set.Items(this, val)
            this.Items = val;
        end

        function set.Value(this, val)
            % value must be scalar for radio buttons
            assert(isscalar(val), "ic:RadioButton:ScalarRequired", ...
                "Value must be a scalar string for RadioButton.");
            this.Value = val;
        end

        function setIcon(this, item, icon)
            % set or replace the icon for a radio item
            % {example}
            % rb = ic.RadioButton("Items", ["A", "B", "C"]);
            % icon = ic.Icon("Source", "star");
            % rb.setIcon("B", icon);
            % {/example}
            arguments
                this
                % one of the #ic.RadioButton.Items to set the icon for
                item (1,1) string
                % the icon to display for the item, or empty to remove the existing icon
                icon ic.Icon {mustBeScalarOrEmpty} = ic.Icon.empty()
            end
            assert(ismember(item, this.Items), "ic:RadioButton:InvalidItem", ...
                "Item '%s' not found. Items: %s.", item, strjoin(this.Items, ", "));

            % remove existing icon in this slot
            existing = this.getIcon(item);
            if ~isempty(existing), delete(existing); end

            % add new icon if provided
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
            % get the icon for a radio item
            % {returns} the #ic.Icon currently set for the item, or an empty value if no icon is set {/returns}
            arguments
                this
                % one of the #ic.RadioButton.Items to get the icon for
                item (1,1) string
            end
            itemIdx = find(this.Items == item, 1);
            if isempty(itemIdx)
                icon = ic.Icon.empty();
                return;
            end
            icons = this.Children(arrayfun(@(c) isa(c, 'ic.Icon'), this.Children));
            if itemIdx <= numel(icons)
                icon = icons(itemIdx);
            else
                icon = ic.Icon.empty();
            end
        end

    end
    methods (Hidden)
        function validateChild(~, child)
            assert(isa(child, "ic.Icon"), "ic:RadioButton:InvalidChild", ...
                "RadioButton only accepts ic.Icon children.");
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the radio group
            out = this.publish("focus", []);
        end
    end
end
