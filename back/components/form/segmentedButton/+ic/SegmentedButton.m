classdef SegmentedButton < ic.core.ComponentContainer
    % > SEGMENTEDBUTTON Group of connected toggle segments with optional icons.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS labels for each segment
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]
        % > VALUE currently selected item(s)
        Value (1,:) string = "Option 1"
        % > MULTISELECT whether multiple segments can be selected
        Multiselect logical = false
        % > SHOWLABELS whether to display text labels (disable for icon-only)
        ShowLabels logical = true
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"
        % > SIZE size of the segments
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > ICONPOSITION position of the icon relative to the label
        IconPosition string {mustBeMember(IconPosition, ...
            ["left", "right"])} = "left"
    end

    methods
        function this = SegmentedButton(props)
            arguments
                props.?ic.SegmentedButton
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = this.Items;

            % When Multiselect is turned off, truncate existing Value
            addlistener(this, 'Multiselect', 'PostSet', ...
                @(~,~) this.onMultiselectChanged());
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
            % Block multi-value assignment when Multiselect is off
            if ~this.Multiselect && numel(val) > 1 %#ok<MCSUP>
                error("ic:SegmentedButton:ScalarRequired", ...
                    "Value must be scalar when Multiselect is false. " + ...
                    "Set Multiselect = true first.");
            end
            this.Value = val;
        end

        function setIcon(this, idx, icon)
            % > SETICON Set or replace the icon for a segment by index.
            %   sb.setIcon(1, ic.Icon.fromName("bold"))
            %   sb.setIcon(2, ic.Icon.fromName("italic"))
            %   sb.setIcon(1, [])  % removes the icon
            arguments
                this
                idx (1,1) double {mustBePositive, mustBeInteger}
                icon
            end
            assert(idx <= numel(this.Items), "ic:SegmentedButton:InvalidIndex", ...
                "Index %d exceeds number of Items (%d).", idx, numel(this.Items));
            item = this.Items(idx);

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

        function icon = getIcon(this, idx)
            % > GETICON Get the icon for a segment by index, or [] if none.
            arguments
                this
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            assert(idx <= numel(this.Items), "ic:SegmentedButton:InvalidIndex", ...
                "Index %d exceeds number of Items (%d).", idx, numel(this.Items));
            item = this.Items(idx);
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
            assert(isa(child, "ic.Icon"), "ic:SegmentedButton:InvalidChild", ...
                "SegmentedButton only accepts ic.Icon children.");
            assert(ismember(target, this.Items), "ic:SegmentedButton:InvalidTarget", ...
                "Target '%s' must match one of the Items: %s.", ...
                target, strjoin(this.Items, ", "));
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
            % > FOCUS programmatically focus the segmented button
            out = this.publish("focus", []);
        end
    end
end
