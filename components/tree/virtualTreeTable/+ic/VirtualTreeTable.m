classdef VirtualTreeTable < ic.core.Component & ic.mixin.Requestable & ic.mixin.HasContextMenu
    % virtual-scrolling tree table for large datasets.
    % Combines a tree with table columns, virtual scrolling, and on-demand data fetching. Only visible rows exist in the DOM. MATLAB owns the full tree; the frontend fetches data on demand via the request/response protocol, requesting root stubs and child chunks as folders are expanded or the user scrolls

    properties (SetObservable, Description = "Reactive")
        % column definitions
        Columns ic.table.Column = ic.table.Column.empty

        % context menu entries for leaf nodes
        LeafContextMenu ic.menu.Entry = ic.menu.Entry.empty

        % context menu entries for folder nodes
        FolderContextMenu ic.menu.Entry = ic.menu.Entry.empty
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % field name of the column with tree indentation ("" = first)
        ExpanderColumn (1,1) string = ""

        % whether the control is disabled and cannot be interacted with
        Disabled (1,1) logical = false

        % whether nodes can be selected
        Selectable (1,1) logical = true

        % size of the control relative to its font size
        Size (1,1) string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % height of the container, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400

        % whether to display tree connector lines
        ShowLine (1,1) logical = true

        % whether to show alternating row colors
        Striped (1,1) logical = false

        % maximum number of selectable items (Inf = unlimited)
        MaxSelectedItems (1,1) double {mustBePositive} = Inf

        % text shown while loading new nodes
        Placeholder (1,1) string = "Loading..."

        % currently sorted column field ("" = no sort)
        SortField (1,1) string = ""

        % sort direction
        SortDirection (1,1) string {mustBeMember(SortDirection, ...
            ["none", "asc", "desc"])} = "none"

        % active column filters
        Filters (1,1) struct = struct()
    end

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % positional key strings
        Value string = string.empty

        % total number of nodes in the current view
        RowCount (1,1) double = 0

        % cache-buster — Svelte clears its caches when this changes
        ViewVersion (1,1) double = 0

        % all folder keys in the view tree (for initial expand)
        InitialExpandedKeys string = string.empty
    end

    properties
        % tree nodes, pulled into the view on demand
        Items ic.tree.Node = ic.tree.Node.empty
    end

    properties (Hidden)
        % print request info to the command window
        Verbose (1,1) logical = false
    end

    properties (Dependent)
        % currently selected #ic.tree.Node handles
        Selection
    end

    % private state
    properties (Access = private)
        % sorted + filtered tree: struct array {node, children}
        % node = ic.tree.Node handle, children = same struct (recursive)
        ViewTree

        % map: view positional key (char) -> ic.tree.Node handle
        ViewKeyMap

        % guard flag: when true, recomputeView skips selection clear
        InCellEdit (1,1) logical = false

        % PostSet listener handles
        ViewListeners event.listener
    end

    events (Description = "Reactive")
        % fires when the user changes the selection
        % {payload}
        % value | cell: positional key strings of selected nodes, or empty if cleared
        % {/payload}
        ValueChanged

        % fires when the user clicks a sortable column header
        % {payload}
        % field | char: field name of the sorted column
        % direction | char: sort direction ('asc' or 'desc')
        % {/payload}
        SortChanged

        % fires when the user changes a column filter
        % {payload}
        % field | char: field name of the filtered column
        % value | any: the filter value (type depends on column type)
        % filters | struct: all current active filters
        % {/payload}
        FilterChanged

        % fires when the user clicks a leaf cell
        % {payload}
        % key | char: positional key string of the clicked node
        % field | char: column field name
        % {/payload}
        CellClicked
    end

    events
        % fires when the user changes the selection (non-reactive). dispatches the resolved Node handles from #ic.VirtualTreeTable.ValueChanged
        % {payload}
        % Selection | ic.tree.Node[]: resolved node handles of the current selection
        % {/payload}
        SelectionChanged

        % fires when the user edits a cell value inline (non-reactive, dispatched from MATLAB)
        % {payload}
        % key | char: positional key string of the edited node
        % field | char: field name of the edited column
        % oldValue | any: previous cell value
        % newValue | any: new cell value after editing
        % {/payload}
        CellEdited

        % fires when the user finishes resizing a column (non-reactive, dispatched from MATLAB)
        % {payload}
        % field | char: field name of the resized column
        % width | double: new column width in pixels
        % {/payload}
        ColumnResized
    end

    methods
        function this = VirtualTreeTable(props)
            arguments
                props.?ic.VirtualTreeTable
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);

            % SelectionChanged listener (fires when Value changes)
            addlistener(this, 'Value', 'PostSet', @(~, ~) notify(this, ...
                'SelectionChanged', ...
                ic.event.MEvent(struct('Selection', this.Selection))));

            % Register request handlers
            this.onRequest("getRoots", @(comp, ~) comp.handleGetRoots());
            this.onRequest("getChildren", ...
                @(comp, data) comp.handleGetChildren(data));

            % Subscribe to Svelte events
            this.subscribe('cellEdited', ...
                @(comp, ~, data) comp.handleCellEdited(data));
            this.subscribe('columnResized', ...
                @(comp, ~, data) comp.handleColumnResized(data));
            this.subscribe('cellAction', ...
                @(comp, ~, data) comp.dispatchCellAction(data));

            % Recompute view when sort/filter state changes
            this.ViewListeners = [
                addlistener(this, 'SortField', 'PostSet', ...
                    @(~, ~) this.recomputeView())
                addlistener(this, 'SortDirection', 'PostSet', ...
                    @(~, ~) this.recomputeView())
                addlistener(this, 'Filters', 'PostSet', ...
                    @(~, ~) this.recomputeView())
            ];

            % Initialize state
            this.ViewKeyMap = containers.Map('KeyType', 'char', ...
                'ValueType', 'any');
            this.ViewTree = struct('node', {}, 'children', {});

            this.recomputeView();
        end

        function delete(this)
            delete(this.ViewListeners);
        end

        function set.Items(this, val)
            this.Items = val;
            % Auto-infer columns if empty
            if isempty(this.Columns) && ~isempty(val) %#ok<MCSUP>
                leaf = findFirstLeaf(val);
                if ~isempty(leaf) && ~isempty(leaf.Data)
                    this.setValueSilently('Columns', ...
                        ic.table.Column.fromStruct(leaf.Data));
                end
            end
            this.recomputeView();
        end

        function set.SortField(this, val)
            if val ~= this.SortField
                this.setValueSilently('SortDirection', 'asc');
            end
            this.SortField = val;
        end

        function set.Value(this, val)
            if isscalar(val) && val == ""
                val = string.empty;
            end
            this.Value = val;
        end

        function nodes = get.Selection(this)
            vals = this.Value;
            if isempty(vals)
                nodes = ic.tree.Node.empty;
                return;
            end
            nodes = ic.tree.Node.empty;
            for i = 1:numel(vals)
                k = char(vals(i));
                if this.ViewKeyMap.isKey(k)
                    nodes(i) = this.ViewKeyMap(k);
                end
            end
        end

        function set.Selection(this, val)
            if isempty(val)
                this.Value = string.empty;
                return;
            end
            keys = strings(1, numel(val));
            for i = 1:numel(val)
                k = this.viewKeyOf(val(i));
                assert(k ~= "", "ic:VirtualTreeTable:NodeNotInView", ...
                    "Node '%s' is not in the current view.", val(i).Label);
                keys(i) = k;
            end
            this.Value = keys;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the tree table container
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
            % programmatically expand a folder node
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            arguments
                this
                % the node to expand
                node (1,1) ic.tree.Node
            end
            key = this.viewKeyOf(node);
            assert(key ~= "", "ic:VirtualTreeTable:NodeNotInView", ...
                "Node '%s' is not in the current view.", node.Label);
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
            key = this.viewKeyOf(node);
            assert(key ~= "", "ic:VirtualTreeTable:NodeNotInView", ...
                "Node '%s' is not in the current view.", node.Label);
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

        function out = editCell(this, node, field, value)
            % programmatically edit a leaf cell. Prefer this method to directly editing the #ic.VirtualTreeTable.Items, as it triggers a view recompute if the cell is in the viewport
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            arguments
                this
                % the node containing the cell to edit
                node (1,1) ic.tree.Node
                % the field name of the cell's column
                field (1,1) string
                % the new value to set. Its type depends on the column definition
                value
            end
            key = this.viewKeyOf(node);
            assert(key ~= "", "ic:VirtualTreeTable:NodeNotInView", ...
                "Node '%s' is not in the current view.", node.Label);

            expander = this.getExpanderField();
            oldValue = [];
            if field == expander
                oldValue = node.Label;
                node.Label = string(value);
            else
                s = node.Data;
                if isfield(s, char(field))
                    oldValue = s.(char(field));
                end
                s.(char(field)) = value;
                node.Data = s;
            end

            out = this.publish("editCell", struct( ...
                'key', char(key), ...
                'field', char(field), ...
                'value', value));

            notify(this, 'CellEdited', ic.event.MEvent(struct( ...
                'key', key, 'field', field, ...
                'oldValue', oldValue, 'newValue', value)));
        end

        function out = refresh(this)
            % manually force a recompute of the view
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            this.recomputeView();
            out = [];
        end
    end

    methods (Access = private)
        function recomputeView(this)
            % build sorted + filtered tree projection.
            if isempty(this.Items)
                this.ViewTree = struct('node', {}, 'children', {});
                this.ViewKeyMap = containers.Map('KeyType', 'char', ...
                    'ValueType', 'any');
                this.RowCount = 0;
                this.InitialExpandedKeys = string.empty;
                this.ViewVersion = this.ViewVersion + 1;
                return;
            end

            % build the view tree (filter + sort, recursive)
            this.ViewTree = this.buildViewTree(this.Items);

            % populate key map eagerly + collect folder keys
            this.ViewKeyMap = containers.Map('KeyType', 'char', ...
                'ValueType', 'any');
            this.buildKeyMap(this.ViewTree, "");
            this.InitialExpandedKeys = this.collectFolderKeys(this.ViewTree, "");

            this.RowCount = this.countNodes(this.ViewTree);

            % clear selection (keys change on sort/filter)
            if ~this.InCellEdit
                this.setValueSilently('Value', string.empty);
            end

            this.ViewVersion = this.ViewVersion + 1;

            if this.Verbose
                fprintf("[VirtualTreeTable] recomputeView → %d nodes\n", ...
                    this.RowCount);
            end
        end

        function viewNodes = buildViewTree(this, nodes)
            % recursively build sorted + filtered view tree.
            n = numel(nodes);
            if n == 0
                viewNodes = struct('node', {}, 'children', {});
                return;
            end

            activeFields = this.getActiveFilterFields();
            hasFilter = ~isempty(activeFields);

            % step 1: Filter + recurse into children
            result = cell(1, n);
            nKeep = 0;

            for i = 1:n
                nd = nodes(i);
                ch = nd.Children;

                if ~isempty(ch)
                    % folder: recurse (children already sorted/filtered)
                    childView = this.buildViewTree(ch);
                    if hasFilter && isempty(childView)
                        continue;
                    end
                    nKeep = nKeep + 1;
                    result{nKeep} = struct('node', nd, ...
                        'children', childView);
                else
                    % leaf: test against all active filters
                    if hasFilter && ~this.passesFilters(nd, activeFields)
                        continue;
                    end
                    nKeep = nKeep + 1;
                    result{nKeep} = struct('node', nd, ...
                        'children', struct('node', {}, 'children', {}));
                end
            end

            if nKeep == 0
                viewNodes = struct('node', {}, 'children', {});
                return;
            end

            viewNodes = [result{1:nKeep}];

            % step 2: Sort this level (children already sorted by recursion)
            if this.SortField ~= "" && this.SortDirection ~= "none" ...
                    && numel(viewNodes) > 1
                viewNodes = this.sortViewLevel(viewNodes);
            end
        end

        function sorted = sortViewLevel(this, viewNodes)
            % sort a single level of view nodes by the current sort field.
            colIdx = find(arrayfun(@(c) c.Field == this.SortField, ...
                this.Columns), 1);
            if isempty(colIdx)
                sorted = viewNodes;
                return;
            end

            col = this.Columns(colIdx);
            expander = this.getExpanderField();
            n = numel(viewNodes);

            sortKeys = cell(1, n);
            isNull = false(1, n);

            for i = 1:n
                nd = viewNodes(i).node;
                if this.SortField == expander
                    raw = string(nd.Label);
                elseif ~isempty(nd.Data) ...
                        && isfield(nd.Data, char(this.SortField))
                    raw = nd.Data.(char(this.SortField));
                else
                    raw = [];
                end

                if isempty(raw) || (isnumeric(raw) && isnan(raw))
                    isNull(i) = true;
                else
                    sortKeys{i} = col.sortKey(raw);
                end
            end

            nonNullIdx = find(~isNull);
            nullIdx = find(isNull);

            if ~isempty(nonNullIdx)
                vals = [sortKeys{nonNullIdx}];
                if this.SortDirection == "asc"
                    [~, order] = sort(vals, 'ascend');
                else
                    [~, order] = sort(vals, 'descend');
                end
                nonNullIdx = nonNullIdx(order);
            end

            sorted = viewNodes([nonNullIdx, nullIdx]);
        end

        function tf = passesFilters(this, node, activeFields)
            % test a leaf node against all active column filters.
            expander = this.getExpanderField();
            filters = this.Filters;

            for k = 1:numel(activeFields)
                field = activeFields{k};

                % Get cell value
                if field == expander
                    cellVal = node.Label;
                elseif ~isempty(node.Data) ...
                        && isfield(node.Data, char(field))
                    cellVal = node.Data.(char(field));
                else
                    cellVal = [];
                end

                % Find column definition
                colIdx = find(arrayfun(@(c) c.Field == field, ...
                    this.Columns), 1);
                if isempty(colIdx), continue; end
                col = this.Columns(colIdx);
                fv = filters.(char(field));

                % isEmpty check
                if isstruct(fv) && isfield(fv, 'isEmpty')
                    if ~(isempty(cellVal) ...
                            || (isstring(cellVal) && cellVal == ""))
                        tf = false;
                        return;
                    end
                    continue;
                end

                % isNotEmpty check
                if isstruct(fv) && isfield(fv, 'isNotEmpty')
                    if isempty(cellVal) ...
                            || (isstring(cellVal) && cellVal == "")
                        tf = false;
                        return;
                    end
                    continue;
                end

                % Empty value doesn't match non-empty filter
                if isempty(cellVal)
                    tf = false;
                    return;
                end

                % type-specific filter
                if ~col.filterColumn(cellVal, fv)
                    tf = false;
                    return;
                end
            end

            tf = true;
        end


        function result = handleGetRoots(this)
            if isempty(this.ViewTree)
                result = [];
            else
                result = this.serializeLevel(this.ViewTree);
            end
            if this.Verbose
                fprintf("[VirtualTreeTable] getRoots → %d root(s)\n", ...
                    numel(this.ViewTree));
            end
        end

        function result = handleGetChildren(this, data)
            viewNode = this.resolveViewNode(data.key);
            if isempty(viewNode) || isempty(viewNode.children)
                result = [];
                if this.Verbose
                    fprintf("[VirtualTreeTable] getChildren key=%s → empty\n", ...
                        data.key);
                end
                return;
            end
            children = viewNode.children;
            nChildren = numel(children);
            startIdx = data.offset + 1;
            if startIdx > nChildren
                result = [];
                return;
            end
            endIdx = min(data.offset + data.count, nChildren);
            slice = children(startIdx:endIdx);
            result = this.serializeLevel(slice, string(data.key), ...
                data.offset);

            if this.Verbose
                fprintf("[VirtualTreeTable] getChildren key=%s " + ...
                    "offset=%d count=%d → %d node(s)\n", ...
                    data.key, data.offset, data.count, numel(slice));
            end
        end

        function stubs = serializeLevel(this, viewNodes, parentKey, offset)
            % serialize view nodes to lightweight stubs for the frontend.
            % Leaf stubs include a .data field with column values.
            arguments
                this
                viewNodes
                parentKey string = ""
                offset double = 0
            end
            n = numel(viewNodes);
            if n == 0
                stubs = [];
                return;
            end

            % generate positional keys
            indices = string(offset + (1:n));
            if parentKey == ""
                keys = indices;
            else
                keys = parentKey + "-" + indices;
            end

            % preallocate struct array
            stubs = repmat(struct('key', '', 'name', '', 'icon', [], ...
                'isFolder', false, 'childCount', 0, 'data', []), 1, n);

            for i = 1:n
                nd = viewNodes(i).node;
                ch = viewNodes(i).children;
                k = char(keys(i));

                stubs(i).key = k;
                stubs(i).name = char(nd.Label);
                if ~isempty(nd.Icon)
                    stubs(i).icon = struct('type', nd.Icon.Type, ...
                        'value', nd.Icon.Value);
                end
                stubs(i).isFolder = ~isempty(ch);
                stubs(i).childCount = numel(ch);

                % leaf nodes: include column data
                if isempty(ch) && ~isempty(nd.Data)
                    stubs(i).data = nd.Data;
                end

                % update key map
                this.ViewKeyMap(k) = nd;
            end
        end

        function viewNode = resolveViewNode(this, key)
            % navigate ViewTree by positional key (e.g. "1-2-3").
            parts = str2double(split(string(key), "-"));
            if isempty(parts) || isnan(parts(1))
                viewNode = [];
                return;
            end
            if parts(1) > numel(this.ViewTree)
                viewNode = [];
                return;
            end
            viewNode = this.ViewTree(parts(1));
            for j = 2:numel(parts)
                if isempty(viewNode.children) ...
                        || parts(j) > numel(viewNode.children)
                    viewNode = [];
                    return;
                end
                viewNode = viewNode.children(parts(j));
            end
        end

        function handleCellEdited(this, data)
            key = string(data.key);
            field = string(data.field);
            newValue = data.newValue;
            oldValue = data.oldValue;

            k = char(key);
            if ~this.ViewKeyMap.isKey(k)
                return;
            end
            node = this.ViewKeyMap(k);

            expander = this.getExpanderField();

            if field == expander
                node.Label = string(newValue);
            else
                s = node.Data;
                colIdx = find(arrayfun(@(c) c.Field == field, ...
                    this.Columns), 1);
                if ~isempty(colIdx)
                    colDef = this.Columns(colIdx);
                    if isfield(s, char(field))
                        newValue = colDef.coerceEditValue(newValue, ...
                            s.(char(field)));
                    else
                        newValue = colDef.coerceEditValue(newValue, []);
                    end
                end
                s.(char(field)) = newValue;
                node.Data = s;
            end

            % conditional recompute (only if edit affects sort/filter)
            needsRecompute = false;
            if this.SortField == field && this.SortDirection ~= "none"
                needsRecompute = true;
            end
            if ~needsRecompute && isfield(this.Filters, char(field))
                fv = this.Filters.(char(field));
                if ~isempty(fv)
                    needsRecompute = true;
                end
            end

            if needsRecompute
                this.InCellEdit = true;
                this.recomputeView();
                this.InCellEdit = false;
            end

            notify(this, 'CellEdited', ic.event.MEvent(struct( ...
                'key', key, 'field', field, ...
                'oldValue', oldValue, 'newValue', newValue)));
        end

        function handleColumnResized(this, data)
            field = string(data.field);
            width = double(data.width);
            cols = this.Columns;
            idx = find(arrayfun(@(c) c.Field == field, cols), 1);
            if ~isempty(idx)
                cols(idx).Width = width;
                this.setValueSilently('Columns', cols);
            end
            notify(this, 'ColumnResized', ic.event.MEvent(struct( ...
                'field', field, 'width', width)));
        end

        function dispatchCellAction(this, data)
            field = string(data.field);
            cols = this.Columns;
            idx = find(arrayfun(@(c) c.Field == field, cols), 1);
            if isempty(idx), return; end
            col = cols(idx);
            if isempty(col.OnCellAction), return; end
            k = char(data.key);
            if this.ViewKeyMap.isKey(k)
                node = this.ViewKeyMap(k);
                col.OnCellAction(col, node, data.data);
            end
        end

        function expander = getExpanderField(this)
            % get the effective expander column field name.
            if this.ExpanderColumn ~= ""
                expander = this.ExpanderColumn;
            elseif ~isempty(this.Columns)
                expander = this.Columns(1).Field;
            else
                expander = "";
            end
        end

        function fields = getActiveFilterFields(this)
            % get the list of fields with active (non-empty) filters.
            fields = {};
            fnames = fieldnames(this.Filters);
            for k = 1:numel(fnames)
                fv = this.Filters.(fnames{k});
                if ~isempty(fv)
                    fields{end+1} = string(fnames{k}); %#ok<AGROW>
                end
            end
        end

        function key = viewKeyOf(this, targetNode)
            % find the view tree positional key for a node handle.
            allKeys = this.ViewKeyMap.keys();
            for j = 1:numel(allKeys)
                if this.ViewKeyMap(allKeys{j}) == targetNode
                    key = string(allKeys{j});
                    return;
                end
            end
            key = "";
        end

        function n = countNodes(this, viewNodes)
            % count total nodes in the view tree (recursive).
            n = numel(viewNodes);
            for i = 1:numel(viewNodes)
                if ~isempty(viewNodes(i).children)
                    n = n + this.countNodes(viewNodes(i).children);
                end
            end
        end

        function buildKeyMap(this, viewNodes, parentKey)
            % populate ViewKeyMap by walking the view tree.
            for i = 1:numel(viewNodes)
                if parentKey == ""
                    key = string(i);
                else
                    key = parentKey + "-" + string(i);
                end
                this.ViewKeyMap(char(key)) = viewNodes(i).node;
                if ~isempty(viewNodes(i).children)
                    this.buildKeyMap(viewNodes(i).children, key);
                end
            end
        end

        function keys = collectFolderKeys(this, viewNodes, parentKey)
            % collect all folder positional keys from the view tree.
            keys = string.empty;
            for i = 1:numel(viewNodes)
                if parentKey == ""
                    key = string(i);
                else
                    key = parentKey + "-" + string(i);
                end
                if ~isempty(viewNodes(i).children)
                    keys(end+1) = key; %#ok<AGROW>
                    keys = [keys, this.collectFolderKeys(viewNodes(i).children, key)]; %#ok<AGROW>
                end
            end
        end
    end
end

function leaf = findFirstLeaf(nodes)
    % find the first leaf node (no children) in a tree.
    leaf = ic.tree.Node.empty;
    for i = 1:numel(nodes)
        if isempty(nodes(i).Children)
            leaf = nodes(i);
            return;
        end
        leaf = findFirstLeaf(nodes(i).Children);
        if ~isempty(leaf), return; end
    end
end
