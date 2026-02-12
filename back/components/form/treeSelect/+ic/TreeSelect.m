classdef TreeSelect < ic.core.Component
    % > TREESELECT Hierarchical multi-value selector with cascading menus.
    %
    %   Displays selected items as closable tags inside the input field.
    %   Opens cascading sub-menus for hierarchical item selection.
    %   Each node (parent or leaf) is independently selectable.
    %   Items are structs with 'key', 'name', 'icon', and 'children' fields.
    %
    %   Example:
    %       ts = ic.TreeSelect();
    %       ts.Items = [
    %           struct('key', 'fruits', 'name', 'Fruits', 'icon', 'apple', 'children', [
    %               struct('key', 'apple',  'name', 'Apple',  'icon', '', 'children', [])
    %               struct('key', 'citrus', 'name', 'Citrus', 'icon', '', 'children', [
    %                   struct('key', 'orange', 'name', 'Orange', 'icon', '', 'children', [])
    %                   struct('key', 'lemon',  'name', 'Lemon',  'icon', '', 'children', [])
    %               ])
    %           ])
    %       ];
    %       ts.Clearable = true;
    %       ts.Value = ["apple", "lemon"];

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS hierarchical tree structure (array of structs with 'key', 'name', 'icon', 'children')
        Items struct = struct('key', {}, 'name', {}, 'icon', {}, 'children', {})
        % > VALUE currently selected node keys (string.empty = no selection)
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
        % > MAXPANELWIDTH maximum width in pixels of each cascade panel
        MaxPanelWidth double {mustBePositive} = 240
        % > OPENONHOVER whether hovering a folder row auto-opens its sub-panel
        OpenOnHover logical = false
    end

    events (Description = "Reactive")
        % > OPENED fires when the dropdown opens
        Opened
        % > CLOSED fires when the dropdown closes
        Closed
    end

    methods
        function this = TreeSelect(props)
            arguments
                props.?ic.TreeSelect
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end

        function set.Value(this, val)
            % Normalize "" to string.empty (canonical "no selection")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            % Validate: every selected key must exist in the tree
            if ~isempty(val) && ~isempty(this.Items) %#ok<MCSUP>
                allKeys = getAllKeys(this.Items); %#ok<MCSUP>
                for i = 1:numel(val)
                    assert(ismember(val(i), allKeys), ...
                        "ic:TreeSelect:InvalidValue", ...
                        "Value '%s' is not a key in Items.", val(i));
                end
            end
            this.Value = val;
        end

        function set.Items(this, val)
            % Validate key uniqueness
            if ~isempty(val)
                allKeys = getAllKeys(val);
                assert(numel(unique(allKeys)) == numel(allKeys), ...
                    "ic:TreeSelect:DuplicateKey", ...
                    "All node keys must be unique across the tree.");
            end
            % Remove any selected keys that are no longer in the new tree
            if ~isempty(this.Value) %#ok<MCSUP>
                if isempty(val)
                    this.Value = string.empty; %#ok<MCSUP>
                else
                    allKeys = getAllKeys(val);
                    keep = ismember(this.Value, allKeys); %#ok<MCSUP>
                    if any(keep)
                        this.Value = this.Value(keep); %#ok<MCSUP>
                    else
                        this.Value = string.empty; %#ok<MCSUP>
                    end
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

function keys = getAllKeys(nodes)
    %GETALLKEYS Recursively collect all 'key' values from a tree of structs.
    keys = string.empty;
    for i = 1:numel(nodes)
        keys(end+1) = string(nodes(i).key); %#ok<AGROW>
        if ~isempty(nodes(i).children)
            keys = [keys, getAllKeys(nodes(i).children)]; %#ok<AGROW>
        end
    end
end
