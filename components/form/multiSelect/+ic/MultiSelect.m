classdef MultiSelect < ic.core.Component
    % multi-value dropdown selector with tags.
    % Provides a searchable dropdown with checkboxes for item selection. Selected items are then displayed as closable tags inside the input field.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % list of selectable options that will appear in the dropdown. They should be unique
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]

        % list of currently selected items
        Value string = string.empty

        % ghost text shown when no items are selected
        Placeholder string = "Select..."

        % whether the control is disabled and cannot be interacted with
        Disabled logical = false

        % whether a closing "x" button should appear on the input field to clear all selected values at once
        Clearable logical = false

        % dimension of the input field and tags relative to the text font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"

        % maximum height of the dropdown popup, in pixels. Content that exceeds this height will be scrollable
        MaxPopupHeight double = 200

        % maximum number of selectable items (Inf = unlimited)
        MaxSelectedItems double {mustBePositive} = Inf
    end

    events (Description = "Reactive")
        % triggered when the user changes the selection
        % {payload}
        % value | cell array or empty: list of selected item labels, or empty if all cleared
        % {/payload}
        ValueChanged

        % fires when the dropdown opens
        Opened

        % fires when the dropdown closes
        Closed
    end

    methods
        function this = MultiSelect(props)
            arguments
                props.?ic.MultiSelect
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end

        function set.Value(this, val)
            % normalize "" to string.empty (canonical "no selection")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            % validate: every selected value must be in Items
            if ~isempty(val) && ~isempty(this.Items) %#ok<MCSUP>
                for i = 1:numel(val)
                    assert(ismember(val(i), this.Items), ...  %#ok<MCSUP>
                        "ic:MultiSelect:InvalidValue", ...
                        "Value '%s' is not a member of Items.", val(i));
                end
            end
            this.Value = val;
        end

        function set.Items(this, val)
            % remove any selected values that are no longer in the new Items
            if ~isempty(this.Value) %#ok<MCSUP>
                keep = ismember(this.Value, val); %#ok<MCSUP>
                if any(keep)
                    this.Value = this.Value(keep); %#ok<MCSUP>
                else
                    this.Value = string.empty; %#ok<MCSUP>
                end
            end
            this.Items = val;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the input field
            out = this.publish("focus", []);
        end

        function out = clear(this)
            % programmatically clear all selected values
            out = this.publish("clear", []);
        end

        function out = open(this)
            % programmatically open the dropdown
            out = this.publish("open", []);
        end

        function out = close(this)
            % programmatically close the dropdown
            out = this.publish("close", []);
        end
    end
end
