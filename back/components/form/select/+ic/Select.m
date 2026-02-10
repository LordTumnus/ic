classdef Select < ic.core.Component
    % > SELECT Single-value dropdown selector.
    %
    %   Displays a trigger field that opens a scrollable dropdown list.
    %   Supports search filtering, clearable selection, and keyboard
    %   navigation.
    %
    %   Example:
    %       s = ic.Select();
    %       s.Items = ["Alpha", "Beta", "Gamma", "Delta"];
    %       s.Searchable = true;
    %       s.Clearable = true;
    %       s.Value = "Beta";

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS list of selectable options
        Items (1,:) string = ["Option 1", "Option 2", "Option 3"]
        % > VALUE currently selected item (string.empty = no selection)
        Value string = string.empty
        % > PLACEHOLDER text shown when no value is selected
        Placeholder string = "Select..."
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > INVALID whether the control is in an invalid state
        Invalid logical = false
        % > ERRORMESSAGE error text shown below the field when invalid
        ErrorMessage string = ""
        % > HELPERTEXT helper text shown below the field
        HelperText string = ""
        % > CLEARABLE whether the selection can be cleared via an X button
        Clearable logical = false
        % > SEARCHABLE whether a search input is shown in the dropdown
        Searchable logical = false
        % > SIZE size of the control
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"
        % > MAXPOPUPHEIGHT maximum height in pixels of the dropdown list
        MaxPopupHeight double = 200
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the selected value changes
        ValueChanged
        % > OPENED fires when the dropdown opens
        Opened
        % > CLOSED fires when the dropdown closes
        Closed
    end

    methods
        function this = Select(id)
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
            % > FOCUS programmatically focus the trigger field
            out = this.publish("focus", []);
        end

        function out = clear(this)
            % > CLEAR programmatically clear the selected value
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
