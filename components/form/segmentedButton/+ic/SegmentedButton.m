classdef SegmentedButton < ic.core.ComponentContainer
    % group of connected toggle segments, from which one or more can be selected

    properties (SetObservable, AbortSet, Description = "Reactive")
        % text labels for each segment
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]

        % list of currently selected items (in #ic.SegmentedButton.Items)
        Value (1,:) string = "Option 1"

        % whether multiple segments can be selected at the same time
        Multiselect logical = false

        % whether to display text labels. If disabled, only the icons will be shown
        ShowLabels logical = true

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"

        % size of the segments relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the control is disabled and cannot be interacted with
        Disabled logical = false

        % position of the icon relative to the text label of each toggle segment
        IconPosition string {mustBeMember(IconPosition, ...
            ["left", "right"])} = "left"

    end

    properties (Description = "Reactive", SetObservable, Access = ?ic.mixin.Reactive)
        % maps item names to icon component IDs for per-item icon rendering
        IconMap struct = struct()
    end

    events (Description = "Reactive")
        % triggered when the user selects or deselects a segment
        % {payload}
        % value | char or cell array: currently selected item(s) after the change
        % {/payload}
        ValueChanged
    end

    methods
        function this = SegmentedButton(props)
            arguments
                props.?ic.SegmentedButton
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);

            % when Multiselect is turned off, truncate existing Value
            addlistener(this, 'Multiselect', 'PostSet', ...
                @(~,~) this.onMultiselectChanged());
        end

        function set.Items(this, val)
            this.Items = val;
        end

        function set.Value(this, val)
            % block multi-value assignment when Multiselect is off
            if ~this.Multiselect && numel(val) > 1 %#ok<MCSUP>
                error("ic:SegmentedButton:ScalarRequired", ...
                    "Value must be scalar when Multiselect is false. " + ...
                    "Set Multiselect = true first.");
            end
            this.Value = val;
        end

        function setIcon(this, item, icon)
            % set, replace or remove the icon for a segment
            % {example}
            % sb = ic.SegmentedButton("Items", ["Bold", "Italic", "Underline"]);
            % sb.setIcon("Bold", ic.Icon("bold"));
            % {/example}
            arguments
                this
                % one of the #ic.SegmentedButton.Items to set the icon for
                item (1,1) string
                % icon to display in the segment, or empty to remove the icon
                icon ic.Icon {mustBeScalarOrEmpty} = ic.Icon.empty
            end
            assert(ismember(item, this.Items), "ic:SegmentedButton:InvalidItem", ...
                "Item '%s' not found. Items: %s.", item, strjoin(this.Items, ", "));

            % remove existing icon in this slot
            existing = this.getIcon(item);
            if ~isempty(existing), delete(existing); end

            % add new icon, if provided
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
            % get the icon for a segment
            % {returns} the #ic.Icon object in the segment, or empty if there is no icon {/returns}
            arguments
                this
                % one of the #ic.SegmentedButton.Items to get the icon for
                item (1,1) string
            end
            assert(ismember(item, this.Items), "ic:SegmentedButton:InvalidItem", ...
                "Item '%s' not found. Items: %s.", item, strjoin(this.Items, ", "));
            itemIdx = find(this.Items == item, 1);
            icons = this.Children(arrayfun(@(c) isa(c, 'ic.Icon'), this.Children));
            if itemIdx <= numel(icons)
                icon = icons(itemIdx);
            else
                icon = [];
            end
        end
    end
    methods (Hidden)
        function validateChild(~, child)
            assert(isa(child, "ic.Icon"), "ic:SegmentedButton:InvalidChild", ...
                "SegmentedButton only accepts ic.Icon children.");
        end
    end

    methods (Access = private)
        function onMultiselectChanged(this)
            if ~this.Multiselect && numel(this.Value) > 1
                this.Value = this.Value(1);
            end
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the segmented button
            out = this.publish("focus", []);
        end
    end
end
