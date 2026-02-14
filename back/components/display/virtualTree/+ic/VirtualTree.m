classdef VirtualTree < ic.core.Component & ic.mixin.Requestable
    % > VIRTUALTREE Virtual-scrolling tree for massive datasets.
    %
    %   Renders a tree view with virtual scrolling and on-demand data
    %   fetching. Only visible rows exist in the DOM (~30-40 elements).
    %   MATLAB owns the full tree; the frontend requests chunks via
    %   request/response protocol.
    %
    %   Example:
    %       vt = ic.VirtualTree();
    %       root = ic.tree.Node("Root");
    %       for i = 1:10000, root.add("Child " + i); end
    %       vt.Items = root;
    %       vt.Selection = root.Children(1);

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > SELECTABLE whether items can be selected
        Selectable logical = true
        % > SIZE size of the control
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > HEIGHT height of the tree (number for px, or CSS string)
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400
        % > SHOWLINE whether to display tree connector lines
        ShowLine logical = true
        % > MAXSELECTEDITEMS maximum number of selectable items (Inf = unlimited)
        MaxSelectedItems double {mustBePositive} = Inf
        % > PLACEHOLDER text shown while loading
        Placeholder string = "Loading..."
    end

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % > VALUE positional key strings (Svelte bridge — hidden from user)
        Value string = string.empty
    end

    properties
        % > ITEMS tree nodes
        Items ic.tree.Node = ic.tree.Node.empty
    end

    properties (Hidden)
        % > VERBOSE print request info to the command window
        Verbose logical = false
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
        % > SELECTIONCHANGED fires when the user changes the selection (carries Selection)
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
            % > FOCUS programmatically focus the tree container
            out = this.publish("focus", []);
        end

        function out = clearSelection(this)
            % > CLEARSELECTION Clear all selected items.
            this.Value = string.empty;
            out = this.publish("clearSelection", []);
        end

        function out = expandNode(this, node)
            % > EXPANDNODE Programmatically expand a folder node.
            arguments, this, node (1,1) ic.tree.Node, end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:VirtualTree:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            out = this.publish("expandNode", struct('key', char(key)));
        end

        function out = collapseNode(this, node)
            % > COLLAPSENODE Programmatically collapse a folder node.
            arguments, this, node (1,1) ic.tree.Node, end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:VirtualTree:NodeNotInTree", ...
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
