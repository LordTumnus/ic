classdef (Abstract) TreeBase < ic.core.Component
    % abstract base for tree-backed components.
    % Provides shared tree node management, incremental node operations, and expand/collapse control

    properties (SetObservable, AbortSet, Description = "Reactive")
        % root tree node(s) that define the hierarchical structure
        Items ic.tree.Node = ic.tree.Node.empty

        % whether the whole tree view is disabled
        Disabled logical = false

        % maximum number of nodes that can be selected simultaneously (Inf = unlimited)
        MaxSelectedItems double {mustBePositive} = Inf
    end

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % positional key strings for the Svelte bridge. See #ic.TreeBase.Selection for the resolved Node handles.
        Value string = string.empty
    end

    properties (Dependent)
        % currently selected nodes as an array of #ic.tree.Node handles
        Selection
    end

    events (Description = "Reactive")
        % fires when the user changes the selection
        % {payload}
        % value | cell array or empty: positional key strings of selected nodes, or empty if cleared
        % {/payload}
        ValueChanged
    end

    events
        % fires when the user changes the selection. This method is a non-reactive convenience event dispatched that listens to #ic.TreeBase.ValueChanged and dispatches the resolved Node handles of the current selection.
        % {payload}
        % Selection | ic.tree.Node[]: resolved node handles of the current selection
        % {/payload}
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
            % normalize "" to string.empty (canonical "no selection")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            % validate: every positional key must resolve in the tree
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
            % resolve positional key strings to Node handles
            nodes = ic.tree.Node.empty;
            for i = 1:numel(this.Value)
                nodes(i) = this.Items.resolve(this.Value(i));
            end
        end

        function set.Selection(this, val)
            % convert Node handles to positional key strings
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
            % add a child node to the tree incrementally.
            % {returns} The new child #ic.tree.Node and a #ic.async.Promise with the fulfillment status from the view{/returns}
            % {example}
            %   [root, ~] = t.addNode(ic.tree.Node.empty, "Root");
            %   [child, ~] = t.addNode(root, "Child", Icon="file");
            % {/example}
            arguments
                this
                % parent node to add under, or empty to create a root node
                parent ic.tree.Node
                % display text for the new node
                label (1,1) string
                % optional icon for the new node
                opts.Icon ic.Asset = ic.Asset()
                % optional data payload for the new node
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
            % remove a node from the tree incrementally
            % {returns} a #ic.async.Promise with the fulfillment status from the view{/returns}
            arguments
                this
                % the node to remove
                node (1,1) ic.tree.Node
            end
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
            % update a node's label, icon, or data incrementally
            % {returns} a #ic.async.Promise with the fulfillment status from the view{/returns}
            arguments
                this
                % the node to update
                node (1,1) ic.tree.Node
                % new label
                opts.Label (1,1) string = node.Label
                % new icon
                opts.Icon = node.Icon
                % new data struct
                opts.Data struct = node.Data
            end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeBase:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            node.Label = opts.Label;
            node.Icon = opts.Icon;
            out = this.publish("updateNode", struct( ...
                'key', char(key), ...
                'label', char(node.Label), ...
                'icon', node.Icon));
        end

        function out = clearSelection(this)
            % clear all selected items
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            this.Value = string.empty;
            out = this.publish("clearSelection", []);
        end

        function out = expandNode(this, node)
            % programmatically expand a folder node
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            arguments
                this
                % the folder node to expand with its children
                node (1,1) ic.tree.Node
            end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeBase:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            out = this.publish("expandNode", struct('key', char(key)));
        end

        function out = collapseNode(this, node)
            % programmatically collapse a folder node
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            arguments
                this
                % the folder node to collapse
                node (1,1) ic.tree.Node
            end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeBase:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            out = this.publish("collapseNode", struct('key', char(key)));
        end

        function out = expandAll(this)
            % expand all folder nodes
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("expandAll", []);
        end

        function out = collapseAll(this)
            % collapse all folder nodes
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("collapseAll", []);
        end
    end
end
