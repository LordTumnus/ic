classdef (Abstract) TreeBase < ic.core.Component
    % > TREEBASE Abstract base for tree-backed components.
    %
    %   Provides shared tree node management (Items, Value/Selection),
    %   incremental operations (addNode, removeNode, updateNode),
    %   and expand/collapse control.
    %
    %   Subclasses: ic.TreeSelect, ic.Tree, (future) ic.FilterTree, ic.TreeTable

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS tree nodes
        Items ic.tree.Node = ic.tree.Node.empty
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > MAXSELECTEDITEMS maximum number of selectable items (Inf = unlimited)
        MaxSelectedItems double {mustBePositive} = Inf
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
        % > VALUECHANGED fires when the user changes the selection
        ValueChanged
    end

    events
        % > SELECTIONCHANGED fires when the user changes the selection (convenience: carries Selection)
        SelectionChanged
    end

    methods
        function this = TreeBase(props)
            this@ic.core.Component(props);
            addlistener(this, 'Value', 'PostSet', @(~, ~) notify(...
                this, ...
                'SelectionChanged', ...
                ic.event.MEvent(struct('Selection', this.Selection))));
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
                assert(~isempty(k), "ic:TreeBase:NodeNotInTree", ...
                    "Node '%s' is not in the Items tree.", val(i).Label);
                keys(i) = k;
            end
            this.Value = keys;
        end
    end

    methods (Description = "Reactive")
        function [child, out] = addNode(this, parent, label, opts)
            % > ADDNODE Add a child node to the tree incrementally.
            %   ts.addNode(ic.tree.Node.empty, "Root")   % add root node
            %   ts.addNode(citrus, "Grape")               % add under citrus
            arguments
                this
                parent ic.tree.Node
                label (1,1) string
                opts.Icon = ic.IconType.empty
                opts.Data struct = struct.empty
            end
            child = ic.tree.Node(label, Icon=opts.Icon, Data=opts.Data);
            if isempty(parent)
                parentKey = "";
                savedValue = this.Value;
                this.setValueSilently('Value', string.empty);
                this.setValueSilently('Items', [this.Items, child]);
                if ~isempty(savedValue)
                    this.setValueSilently('Value', savedValue);
                end
            else
                parentKey = this.Items.keyOf(parent);
                assert(~isempty(parentKey), "ic:TreeBase:NodeNotInTree", ...
                    "Parent node '%s' is not in the Items tree.", parent.Label);
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

        function out = removeNode(this, node)
            % > REMOVENODE Remove a node from the tree incrementally.
            %   ts.removeNode(orange)
            arguments, this, node (1,1) ic.tree.Node, end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeBase:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            parts = sscanf(key, '%d-');
            if isscalar(parts)
                this.setValueSilently('Value', string.empty);
                items = this.Items;
                items(parts(1)) = [];
                this.setValueSilently('Items', items);
            else
                this.Items.remove(key);
                if ~isempty(this.Value)
                    keep = ~(this.Value == key | startsWith(this.Value, key + "-"));
                    this.setValueSilently('Value', this.Value(keep));
                end
            end
            out = this.publish("removeNode", struct('key', char(key)));
        end

        function out = updateNode(this, node, opts)
            % > UPDATENODE Update a node's label or icon incrementally.
            %   ts.updateNode(apple, Label="Green Apple")
            arguments
                this
                node (1,1) ic.tree.Node
                opts.Label (1,1) string = ""
                opts.Icon = []
                opts.Data struct = struct.empty
            end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeBase:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
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

        function out = clearSelection(this)
            % > CLEARSELECTION Clear all selected items.
            this.Value = string.empty;
            out = this.publish("clearSelection", []);
        end

        function out = expandNode(this, node)
            % > EXPANDNODE Programmatically expand a folder node.
            %   t.expandNode(citrus)
            arguments, this, node (1,1) ic.tree.Node, end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeBase:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            out = this.publish("expandNode", struct('key', char(key)));
        end

        function out = collapseNode(this, node)
            % > COLLAPSENODE Programmatically collapse a folder node.
            %   t.collapseNode(citrus)
            arguments, this, node (1,1) ic.tree.Node, end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeBase:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            out = this.publish("collapseNode", struct('key', char(key)));
        end

        function out = expandAll(this)
            % > EXPANDALL Expand all folder nodes.
            out = this.publish("expandAll", []);
        end

        function out = collapseAll(this)
            % > COLLAPSEALL Collapse all folder nodes.
            out = this.publish("collapseAll", []);
        end
    end
end
