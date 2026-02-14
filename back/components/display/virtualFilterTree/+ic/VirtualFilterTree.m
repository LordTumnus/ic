classdef VirtualFilterTree < ic.core.Component & ic.mixin.Requestable
    % > VIRTUALFILTERTREE Virtual-scrolling tree with server-side filtering.
    %
    %   Renders a VirtualTree for normal browsing. When filter tags are
    %   entered, sends a filter request to MATLAB, which walks the full
    %   tree and returns matching nodes as a regular tree structure.
    %
    %   Operators:
    %     (none) = contains, | = OR, ~ = NOT, : = folder-only,
    %     @ = leaf-only, = = exact, / = ancestor path, ^ = starts-with
    %
    %   Example:
    %       vft = ic.VirtualFilterTree();
    %       root = ic.tree.Node("Root");
    %       for i = 1:10000, root.add("Child " + i); end
    %       vft.Items = root;

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
        % > PLACEHOLDER text shown while loading in VirtualTree mode
        Placeholder string = "Loading..."
        % > SEARCHPLACEHOLDER text shown in the search bar when empty
        SearchPlaceholder string = "Search..."
        % > CLEARABLE whether the search bar can be cleared via X button
        Clearable logical = true
        % > CASESENSITIVE whether filtering is case-sensitive
        CaseSensitive logical = false
        % > AUTOEXPAND auto-expand ancestors of matches in filtered view
        AutoExpand logical = true
    end

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % > VALUE positional key strings (Svelte bridge — hidden from user)
        Value string = string.empty
        % > SEARCHVALUE current filter tags (Svelte bridge — hidden from user)
        SearchValue string = string.empty
    end

    properties
        % > ITEMS tree nodes (not reactive — pull-based)
        Items ic.tree.Node = ic.tree.Node.empty
    end

    properties (Hidden)
        % > VERBOSE print request info to the command window
        Verbose logical = false
    end

    properties (Access = private)
        FilterActive_ logical = false
        FilterRoots_ = []            % struct array of VirtualNode stubs (top-level)
        FilterChildMap_              % containers.Map: parentKey → struct array of child stubs
        FilterExpandKeys_ = {}       % cell array of folder keys to auto-expand
    end

    properties (Dependent)
        % > SELECTION currently selected nodes (user-facing API)
        Selection
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the user changes the selection
        ValueChanged
        % > SEARCHCHANGED fires when the filter tags change
        SearchChanged
    end

    events
        % > SELECTIONCHANGED fires when the user changes the selection (carries Selection)
        SelectionChanged
    end

    methods
        function this = VirtualFilterTree(props)
            arguments
                props.?ic.VirtualFilterTree
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.FilterChildMap_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            addlistener(this, 'Value', 'PostSet', @(~, ~) notify( ...
                this, ...
                'SelectionChanged', ...
                ic.event.MEvent(struct('Selection', this.Selection))));

            % Register request handlers
            this.onRequest("getRoots", @(comp, ~) comp.handleGetRoots());
            this.onRequest("getChildren", @(comp, data) comp.handleGetChildren(data));
            this.onRequest("filter", @(comp, data) comp.handleFilter(data));
            this.onRequest("clearFilter", @(comp, ~) comp.handleClearFilter());
        end

        function set.Value(this, val)
            if isscalar(val) && val == ""
                val = string.empty;
            end
            items = this.Items; %#ok<MCSUP>
            if ~isempty(val) && ~isempty(items)
                for i = 1:numel(val)
                    items.resolve(val(i));
                end
            end
            this.Value = val;
        end

        function set.SearchValue(this, val)
            if isscalar(val) && val == ""
                val = string.empty;
            end
            this.SearchValue = val;
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
                assert(~isempty(k), "ic:VirtualFilterTree:NodeNotInTree", ...
                    "Node '%s' is not in the Items tree.", val(i).Label);
                keys(i) = k;
            end
            this.Value = keys;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the search input
            out = this.publish("focus", []);
        end

        function out = clearSelection(this)
            % > CLEARSELECTION Clear all selected items.
            this.Value = string.empty;
            out = this.publish("clearSelection", []);
        end

        function out = clearSearch(this)
            % > CLEARSEARCH programmatically clear all filter tags
            this.SearchValue = string.empty;
            out = this.publish("clearSearch", []);
        end

        function out = expandNode(this, node)
            % > EXPANDNODE Programmatically expand a folder node.
            arguments, this, node (1,1) ic.tree.Node, end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:VirtualFilterTree:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);
            out = this.publish("expandNode", struct('key', char(key)));
        end

        function out = collapseNode(this, node)
            % > COLLAPSENODE Programmatically collapse a folder node.
            arguments, this, node (1,1) ic.tree.Node, end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:VirtualFilterTree:NodeNotInTree", ...
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
            if this.FilterActive_
                if this.Verbose
                    fprintf("[VirtualFilterTree] getRoots (filtered) → %d root(s)\n", numel(this.FilterRoots_));
                end
                result = this.FilterRoots_;
                if isempty(result), result = []; end
            else
                if this.Verbose
                    fprintf("[VirtualFilterTree] getRoots → %d root(s)\n", numel(this.Items));
                end
                result = this.serializeLevel(this.Items);
            end
        end

        function result = handleGetChildren(this, data)
            if this.FilterActive_
                % Serve from filter cache
                k = char(data.key);
                if this.FilterChildMap_.isKey(k)
                    stubs = this.FilterChildMap_(k);
                    result = this.paginateStubs(stubs, data.offset, data.count);
                    if this.Verbose
                        fprintf("[VirtualFilterTree] getChildren (filtered) key=%s → %d stub(s)\n", ...
                            k, numel(result));
                    end
                else
                    result = [];
                end
            else
                parent = this.Items.resolve(data.key);
                children = parent.Children;
                nChildren = numel(children);
                startIdx = data.offset + 1;
                if startIdx > nChildren
                    if this.Verbose
                        fprintf("[VirtualFilterTree] getChildren key=%s offset=%d → out of range (%d children)\n", ...
                            data.key, data.offset, nChildren);
                    end
                    result = [];
                    return;
                end
                endIdx = min(data.offset + data.count, nChildren);
                slice = children(startIdx:endIdx);
                if this.Verbose
                    fprintf("[VirtualFilterTree] getChildren key=%s offset=%d count=%d → %d node(s)\n", ...
                        data.key, data.offset, data.count, numel(slice));
                end
                result = this.serializeLevel(slice, data.key, data.offset);
            end
        end

        function result = handleFilter(this, data)
            % Walk the full tree applying filter logic, cache results,
            % and return a summary (not the full tree).
            if this.Verbose
                fprintf("[VirtualFilterTree] filter request\n");
            end
            groups = data.groups;
            cs = logical(data.caseSensitive);

            % Build nested filtered struct
            nested = this.filterNodes(this.Items, groups, cs, {}, "");

            % Flatten into cache: roots + child map
            this.FilterChildMap_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            this.FilterExpandKeys_ = {};
            if isempty(nested)
                this.FilterRoots_ = [];
            else
                this.FilterRoots_ = this.buildFilterStubs(nested);
            end
            this.FilterActive_ = true;

            n = numel(this.FilterRoots_);
            if this.Verbose
                fprintf("[VirtualFilterTree] filter cached → %d root(s), %d folder(s)\n", ...
                    n, numel(this.FilterExpandKeys_));
            end

            % Return summary — Svelte uses this to re-key VirtualTree
            result = struct('count', n, 'expandKeys', {this.FilterExpandKeys_});
        end

        function result = handleClearFilter(this)
            % Clear the filter cache, reverting to full Items tree.
            this.FilterActive_ = false;
            this.FilterRoots_ = [];
            this.FilterChildMap_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            this.FilterExpandKeys_ = {};
            if this.Verbose
                fprintf("[VirtualFilterTree] filter cleared\n");
            end
            result = true;
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
            indices = string(offset + (1:n));
            if parentKey == ""
                keys = indices;
            else
                keys = parentKey + "-" + indices;
            end
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

        function stubs = buildFilterStubs(this, nodes)
            % Flatten nested filter struct into VirtualNode stubs.
            % Populates FilterChildMap_ and FilterExpandKeys_ as side effects.
            n = numel(nodes);
            stubs = repmat(struct('key', '', 'name', '', 'icon', [], ...
                'isFolder', false, 'childCount', 0), 1, n);
            for i = 1:n
                nd = nodes(i);
                hasChildren = isstruct(nd.children) && ~isempty(nd.children);
                childCount = 0;
                if hasChildren, childCount = numel(nd.children); end
                stubs(i) = struct('key', nd.key, 'name', nd.name, ...
                    'icon', nd.icon, 'isFolder', hasChildren, ...
                    'childCount', childCount);
                if hasChildren
                    childStubs = this.buildFilterStubs(nd.children);
                    this.FilterChildMap_(char(nd.key)) = childStubs;
                    this.FilterExpandKeys_{end+1} = char(nd.key);
                end
            end
        end

        function result = paginateStubs(~, stubs, offset, count)
            % Return a paginated slice of a stub array.
            n = numel(stubs);
            startIdx = offset + 1;
            if startIdx > n
                result = [];
                return;
            end
            endIdx = min(offset + count, n);
            result = stubs(startIdx:endIdx);
        end

        function result = filterNodes(this, nodes, groups, cs, ancestorPath, parentKey)
            % Recursively filter nodes, preserving positional keys.
            % Returns struct array in TreeNode format (key, name, icon, children).
            result = [];
            for i = 1:numel(nodes)
                nd = nodes(i);

                % Compute positional key inline
                if parentKey == ""
                    key = string(i);
                else
                    key = parentKey + "-" + string(i);
                end

                isFolder = ~isempty(nd.Children);

                % Recurse into children
                if isFolder
                    childPath = [ancestorPath, {char(nd.Label)}];
                    filteredChildren = this.filterNodes( ...
                        nd.Children, groups, cs, childPath, key);
                else
                    filteredChildren = [];
                end

                % Check if this node matches
                selfMatch = this.matchNodeMATLAB( ...
                    nd.Label, isFolder, ancestorPath, groups, cs);

                if selfMatch || ~isempty(filteredChildren)
                    if isempty(nd.Icon)
                        icon = [];
                    else
                        icon = struct('type', nd.Icon.Type, 'value', nd.Icon.Value);
                    end
                    entry = struct( ...
                        'key', char(key), ...
                        'name', char(nd.Label), ...
                        'icon', icon, ...
                        'children', []);
                    if ~isempty(filteredChildren)
                        entry.children = filteredChildren;
                    end
                    result = [result, entry]; %#ok<AGROW>
                end
            end
        end

        function tf = matchNodeMATLAB(~, name, isFolder, ancestorPath, groups, cs)
            % MATLAB-side implementation of filter matching logic.
            if cs
                n = char(name);
                norm = @(s) char(s);
            else
                n = lower(char(name));
                norm = @(s) lower(char(s));
            end

            tf = true;

            % ALL contains (AND)
            if isfield(groups, 'contains') && ~isempty(groups.contains)
                terms = groups.contains;
                if ~iscell(terms), terms = {terms}; end
                for j = 1:numel(terms)
                    if ~contains(n, norm(terms{j}))
                        tf = false; return;
                    end
                end
            end

            % ALL folder tags (AND, must be folder)
            if isfield(groups, 'folder') && ~isempty(groups.folder)
                terms = groups.folder;
                if ~iscell(terms), terms = {terms}; end
                for j = 1:numel(terms)
                    if ~isFolder || ~contains(n, norm(terms{j}))
                        tf = false; return;
                    end
                end
            end

            % ALL leaf tags (AND, must be leaf)
            if isfield(groups, 'leaf') && ~isempty(groups.leaf)
                terms = groups.leaf;
                if ~iscell(terms), terms = {terms}; end
                for j = 1:numel(terms)
                    if isFolder || ~contains(n, norm(terms{j}))
                        tf = false; return;
                    end
                end
            end

            % ALL exact tags (AND)
            if isfield(groups, 'exact') && ~isempty(groups.exact)
                terms = groups.exact;
                if ~iscell(terms), terms = {terms}; end
                for j = 1:numel(terms)
                    if ~strcmp(n, norm(terms{j}))
                        tf = false; return;
                    end
                end
            end

            % ALL starts tags (AND)
            if isfield(groups, 'starts') && ~isempty(groups.starts)
                terms = groups.starts;
                if ~iscell(terms), terms = {terms}; end
                for j = 1:numel(terms)
                    if ~startsWith(n, norm(terms{j}))
                        tf = false; return;
                    end
                end
            end

            % ALL path tags (AND, ancestor path)
            if isfield(groups, 'path') && ~isempty(groups.path)
                terms = groups.path;
                if ~iscell(terms), terms = {terms}; end
                for j = 1:numel(terms)
                    nt = norm(terms{j});
                    found = false;
                    for k = 1:numel(ancestorPath)
                        if contains(norm(ancestorPath{k}), nt)
                            found = true; break;
                        end
                    end
                    if ~found
                        tf = false; return;
                    end
                end
            end

            % ANY or tag must match (OR)
            if isfield(groups, 'or') && ~isempty(groups.or)
                terms = groups.or;
                if ~iscell(terms), terms = {terms}; end
                anyMatch = false;
                for j = 1:numel(terms)
                    if contains(n, norm(terms{j}))
                        anyMatch = true; break;
                    end
                end
                if ~anyMatch
                    tf = false; return;
                end
            end

            % NO not tag must match (NOT)
            if isfield(groups, 'not') && ~isempty(groups.not)
                terms = groups.not;
                if ~iscell(terms), terms = {terms}; end
                for j = 1:numel(terms)
                    if contains(n, norm(terms{j}))
                        tf = false; return;
                    end
                end
            end
        end
    end
end
