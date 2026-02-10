classdef MultiSelect < ic.core.Component
    % > MULTISELECT Multi-value dropdown selector with tags.
    %
    %   Displays selected items as closable tags inside the input field.
    %   Provides a searchable dropdown with checkboxes for item selection.
    %   Tags can be reordered with keyboard shortcuts.
    %
    %   Example:
    %       ms = ic.MultiSelect();
    %       ms.Items = ["Alpha", "Beta", "Gamma", "Delta"];
    %       ms.Clearable = true;
    %       ms.Value = ["Alpha", "Gamma"];

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS list of selectable options
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]
        % > VALUE currently selected items (string.empty = no selection)
        Value string = string.empty
        % > PLACEHOLDER text shown when no items are selected
        Placeholder string = "Select..."
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > CLEARABLE whether all selections can be cleared via an X button
        Clearable logical = false
        % > SIZE size of the control
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"
        % > MAXPOPUPHEIGHT maximum height in pixels of the dropdown list
        MaxPopupHeight double = 200
        % > MAXSELECTEDITEMS maximum number of selectable items (Inf = unlimited)
        MaxSelectedItems double {mustBePositive} = Inf
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the selected values change
        ValueChanged
        % > OPENED fires when the dropdown opens
        Opened
        % > CLOSED fires when the dropdown closes
        Closed
    end

    methods
        function this = MultiSelect(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end

        function set.Value(this, val)
            % Normalize "" to string.empty (canonical "no selection")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            % Validate: every selected value must be in Items
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
            % Remove any selected values that are no longer in the new Items
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
            % > FOCUS programmatically focus the input field
            out = this.publish("focus", []);
        end

        function out = clear(this)
            % > CLEAR programmatically clear all selected values
            out = this.publish("clear", []);
        end

        function out = open(this)
            % > OPEN programmatically open the dropdown
            out = this.publish("open", []);
        end

        function out = close(this)
            % > CLOSE programmatically close the dropdown
            out = this.publish("close", []);
        end
    end
end
