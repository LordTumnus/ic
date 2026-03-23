classdef Select < ic.core.Component
    % single-value dropdown selector.
    % Displays a trigger field that opens a scrollable dropdown list. Supports search filtering, clearable selection, and keyboard navigation.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % list of selectable options
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]

        % currently selected item from #ic.Select.Items, or string.empty if no selection
        Value string = string.empty

        % ghost text shown when no value is selected
        Placeholder string = "Select..."

        % whether the control is disabled and cannot be interacted with
        Disabled logical = false

        % whether the control is in an invalid state, in which case it is highlighted with an error color and the #ic.Select.ErrorMessage text is shown
        Invalid logical = false

        %  error text shown below the field when #ic.Select.Invalid is true
        ErrorMessage string = ""

        % text shown below the field
        HelperText string = ""

        % whether a "x" clear button is shown in the trigger field to clear the selection
        Clearable logical = false

        % whether the search input can be used to filter the dropdown options
        Searchable logical = false

        % size of the control relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"

        % maximum height of the popup dropdown list, in pixels. If the content exceeds this height, the dropdown becomes scrollable.
        MaxPopupHeight double = 200
    end

    events (Description = "Reactive")
        % triggered when the user selects or clears a value
        ValueChanged

        % fires when the dropdown opens
        Opened

        % fires when the dropdown closes
        Closed
    end

    methods
        function this = Select(props)
            arguments
                props.?ic.Select
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end

        function set.Value(this, val)
            % normalize "" to string.empty (canonical "no selection")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            if ~isempty(val) && ~isempty(this.Items) %#ok<MCSUP>
                assert(ismember(val, this.Items), ...  %#ok<MCSUP>
                    "ic:Select:InvalidValue", ...
                    "Value '%s' is not a member of Items.", val);
            end
            this.Value = val;
        end

        function set.Items(this, val)
            if ~isempty(this.Value) && ~ismember(this.Value, val) %#ok<MCSUP>
                this.Value = string.empty; %#ok<MCSUP>
            end
            this.Items = val;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programatically focus the trigger field
            out = this.publish("focus", []);
        end

        function out = clear(this)
            % programmatically clear the selected value
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
