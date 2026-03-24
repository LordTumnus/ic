classdef VirtualTree < ic.core.Component & ...
                       ic.mixin.Requestable & ...
                       ic.mixin.HasContextMenu
    % virtual-scrolling tree for massive datasets.
    % Renders only the visible rows in the DOM using fixed-height virtual scrolling. MATLAB owns the full tree; the frontend fetches data on demand via the request/response protocol, requesting root stubs and child chunks as folders are expanded or the user scrolls.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether the tree is disabled and cannot be interacted with
        Disabled logical = false

        % whether items can be selected
        Selectable logical = true

        % size of the tree relative to its font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % height of the tree, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400

        % whether to display tree connector lines
        ShowLine logical = true

        % maximum number of selectable items (Inf = unlimited)
        MaxSelectedItems double {mustBePositive} = Inf

        % ghost text shown while loading
        Placeholder string = "Loading..."
    end

    properties (SetObservable, Description = "Reactive")
        % context menu entries for leaf nodes
        LeafContextMenu ic.menu.Entry = ic.menu.Entry.empty

        % context menu entries for folder nodes
        FolderContextMenu ic.menu.Entry = ic.menu.Entry.empty
    end

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % positional key strings for the Svelte bridge (hidden from user)
        Value string = string.empty
    end

    properties
        % root tree nodes that form the basis of the tree structure
        Items ic.tree.Node = ic.tree.Node.empty
    end

    properties (Hidden)
        % print request info to the command window
        Verbose logical = false
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
        % fires when the user changes the selection. This event is a non-reactive convenience event dispatched with the resolved selection from #ic.VirtualTree.ValueChanged
        % {payload}
        % Selection | ic.tree.Node array: resolved node handles of the current selection
        % {/payload}
        SelectionChanged
    end

    methods
        function this = VirtualTree(props)
            arguments
                props.?ic.VirtualTree
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            addlistener(this, 'Value', 'PostSet', @(~, ~) notify( ...
                this, ...
                'SelectionChanged', ...
                ic.event.MEvent(struct('Selection', this.Selection))));

            % Register request handlers
            this.onRequest("getRoots", @(comp, ~) comp.handleGetRoots());
            this.onRequest("getChildren", @(comp, data) comp.handleGetChildren(data));
        end

        function set.Value(this, val)
            % Normalize "" to string.empty (canonical "no selection")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            % Validate: every positional key must resolve in the tree
            items = this.Items; %#ok<MCSUP>
            if ~isempty(val) && ~isempty(items)
                for i = 1:numel(val)
                    items.resolve(val(i));
                end
            end
            this.Value = val;
        end

        function nodes = get.Selection(this)
            vals = this.Value;
            if isempty(vals)
                nodes = ic.tree.Node.empty;
                return;
            end
            items = this.Items;
            nodes = ic.tree.Node.empty;
            for i = 1:numel(vals)
                nodes(i) = items.resolve(vals(i));
            end
        end

        function set.Selection(this, val)
            if isempty(val)
                this.Value = string.empty;
                return;
            end
            items = this.Items;
            keys = strings(1, numel(val));
            for i = 1:numel(val)
                k = items.keyOf(val(i));
                assert(~isempty(k), "ic:VirtualTree:NodeNotInTree", ...
                    "Node '%s' is not in the Items tree.", val(i).Label);
                keys(i) = k;
            end
            this.Value = keys;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the tree container
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("focus", []);
        end

        function out = clearSelection(this)
            % clear all selected items
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            this.Value = string.empty;
            out = this.publish("clearSelection", []);
        end

        function out = expandNode(this, node)
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            % programmatically expand a folder node
            arguments
                this
                % the node to expand
                node (1,1) ic.tree.Node
            end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:VirtualTree:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            out = this.publish("expandNode", struct('key', char(key)));
        end

        function out = collapseNode(this, node)
            % programmatically collapse a folder node
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}

            arguments
                this
                % the node to collapse
                node (1,1) ic.tree.Node
            end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:VirtualTree:NodeNotInTree", ...
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

    methods (Access = private)
        function result = handleGetRoots(this)
            if this.Verbose
                fprintf("[VirtualTree] getRoots → %d root(s)\n", numel(this.Items));
            end
            result = this.serializeLevel(this.Items);
        end

        function result = handleGetChildren(this, data)
            parent = this.Items.resolve(data.key);
            children = parent.Children;
            nChildren = numel(children);
            startIdx = data.offset + 1;
            if startIdx > nChildren
                if this.Verbose
                    fprintf("[VirtualTree] getChildren key=%s offset=%d → out of range (%d children)\n", ...
                        data.key, data.offset, nChildren);
                end
                result = [];
                return;
            end
            endIdx = min(data.offset + data.count, nChildren);
            slice = children(startIdx:endIdx);
            if this.Verbose
                fprintf("[VirtualTree] getChildren key=%s offset=%d count=%d → %d node(s)\n", ...
                    data.key, data.offset, data.count, numel(slice));
            end
            result = this.serializeLevel(slice, data.key, data.offset);
        end

        function stubs = serializeLevel(~, nodes, parentKey, offset)
            arguments
                ~
                nodes ic.tree.Node
                parentKey string = ""
                offset double = 0
            end
            n = numel(nodes);
            if n == 0
                stubs = [];
                return;
            end
            % Vectorize key generation
            indices = string(offset + (1:n));
            if parentKey == ""
                keys = indices;
            else
                keys = parentKey + "-" + indices;
            end
            % Preallocate struct array
            stubs = repmat(struct('key', '', 'name', '', 'icon', [], ...
                'isFolder', false, 'childCount', 0), 1, n);
            for i = 1:n
                nd = nodes(i);
                stubs(i).key = char(keys(i));
                stubs(i).name = char(nd.Label);
                if ~isempty(nd.Icon)
                    stubs(i).icon = struct('type', nd.Icon.Type, ...
                        'value', nd.Icon.Value);
                end
                ch = nd.Children;
                stubs(i).isFolder = ~isempty(ch);
                stubs(i).childCount = numel(ch);
            end
        end
    end
end
