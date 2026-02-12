classdef TreeSelect < ic.core.Component
    % > TREESELECT Hierarchical multi-value selector with cascading menus.
    %
    %   Displays selected items as closable tags inside the input field.
    %   Opens cascading sub-menus for hierarchical item selection.
    %   Items are ic.tree.Node objects; selection is done via Node handles.
    %
    %   Example:
    %       ts = ic.TreeSelect();
    %       fruits = ic.tree.Node("Fruits", Icon=ic.IconType.lucide("apple"));
    %       apple  = fruits.add("Apple");
    %       citrus = fruits.add("Citrus");
    %       orange = citrus.add("Orange");
    %       lemon  = citrus.add("Lemon");
    %       ts.Items = fruits;
    %       ts.Selection = [apple, lemon];

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS tree nodes
        Items ic.tree.Node = ic.tree.Node.empty
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

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.core.ComponentBase, Hidden)
        % > VALUE positional key strings (Svelte bridge — hidden from user)
        Value string = string.empty
    end

    properties (Dependent)
        % > SELECTION currently selected nodes (user-facing API)
        Selection
    end

    events (Description = "Reactive")
        % > OPENED fires when the dropdown opens
        Opened
        % > CLOSED fires when the dropdown closes
        Closed
    end

    events
        % > SELECTIONCHANGED fires when the selection changes
        SelectionChanged
    end

    methods
        function this = TreeSelect(props)
            arguments
                props.?ic.TreeSelect
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            addlistener(this, 'Value', 'PostSet', @(~,~) notify(this, 'SelectionChanged'));
        end

        function set.Value(this, val)
            % Normalize "" to string.empty (canonical "no selection")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            % Validate: every positional key must resolve in the tree
            if ~isempty(val) && ~isempty(this.Items) %#ok<MCSUP>
                for i = 1:numel(val)
                    this.Items.resolve(val(i)); %#ok<MCSUP>
                end
            end
            this.Value = val;
        end

        function set.Items(this, val)
            this.Value = string.empty; %#ok<MCSUP>
            this.Items = val;
        end

        function nodes = get.Selection(this)
            % Resolve positional key strings → Node handles
            nodes = ic.tree.Node.empty;
            for i = 1:numel(this.Value)
                nodes(i) = this.Items.resolve(this.Value(i));
            end
        end

        function set.Selection(this, val)
            % Convert Node handles → positional key strings via keyOf
            if isempty(val)
                this.Value = string.empty;
                return;
            end
            keys = strings(1, numel(val));
            for i = 1:numel(val)
                k = this.Items.keyOf(val(i));
                assert(k ~= "", "ic:TreeSelect:NodeNotInTree", ...
                    "Node '%s' is not in the Items tree.", val(i).Label);
                keys(i) = k;
            end
            this.Value = keys;
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

        function out = addNode(this, parentKey, label, opts)
            % > ADDNODE Add a child node to the tree incrementally.
            %   ts.addNode("", "Root")         % add root node
            %   ts.addNode("1-2", "Grape")     % add under node 1-2
            arguments
                this
                parentKey (1,1) string
                label (1,1) string
                opts.Icon = ic.IconType.empty
                opts.Data struct = struct.empty
            end
            child = ic.tree.Node(label, Icon=opts.Icon, Data=opts.Data);
            if parentKey == ""
                % Root-level: must go through setter. Use setValueSilently
                % to suppress the framework notification to Svelte.
                % Pre-clear Value so set.Items' this.Value=string.empty
                % is a no-op (AbortSet sees same value).
                savedValue = this.Value;
                this.setValueSilently('Value', string.empty);
                this.setValueSilently('Items', [this.Items, child]);
                if ~isempty(savedValue)
                    this.setValueSilently('Value', savedValue);
                end
            else
                parent = this.Items.resolve(parentKey);
                parent.Children(end+1) = child;
            end
            if isempty(opts.Icon)
                icon = [];
            else
                icon = struct('type', opts.Icon.Type, 'value', opts.Icon.Value);
            end
            out = this.publish("addNode", struct( ...
                'parentKey', char(parentKey), ...
                'label', char(label), ...
                'icon', icon));
        end

        function out = removeNode(this, key)
            % > REMOVENODE Remove a node from the tree incrementally.
            %   ts.removeNode("1-2-1")
            arguments, this, key (1,1) string, end
            parts = sscanf(key, '%d-');
            if isscalar(parts)
                % Root-level: keys shift after removal, so clear Value
                % and let Svelte send back remapped values via publish().
                this.setValueSilently('Value', string.empty);
                items = this.Items;
                items(parts(1)) = [];
                this.setValueSilently('Items', items);
            else
                % Nested: handle mutation, no Items setter triggered.
                this.Items.remove(key);
                % Drop removed key + descendants from Value silently.
                if ~isempty(this.Value)
                    keep = ~(this.Value == key | startsWith(this.Value, key + "-"));
                    this.setValueSilently('Value', this.Value(keep));
                end
            end
            out = this.publish("removeNode", struct('key', char(key)));
        end

        function out = updateNode(this, key, opts)
            % > UPDATENODE Update a node's label or icon incrementally.
            %   ts.updateNode("1-1", Label="Green Apple")
            arguments
                this
                key (1,1) string
                opts.Label (1,1) string = ""
                opts.Icon = []
                opts.Data struct = struct.empty
            end
            node = this.Items.resolve(key);
            if opts.Label ~= "", node.Label = opts.Label; end
            if ~isempty(opts.Icon), node.Icon = opts.Icon; end
            if ~isempty(opts.Data), node.Data = opts.Data; end
            if isempty(node.Icon), icon = [];
            else, icon = struct('type', node.Icon.Type, 'value', node.Icon.Value);
            end
            out = this.publish("updateNode", struct( ...
                'key', char(key), ...
                'label', char(node.Label), ...
                'icon', icon));
        end
    end
end
