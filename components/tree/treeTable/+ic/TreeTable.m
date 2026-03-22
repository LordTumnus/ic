classdef TreeTable < ic.TreeBase & ic.mixin.HasContextMenu
    % > TREETABLE Hierarchical tree with aligned table columns.
    %
    %   Displays tree-structured data with sortable/filterable columns.
    %   Folder nodes render as full-width expand/collapse rows.
    %   Leaf nodes render with per-column cells (text, number, etc.).
    %
    %   Example:
    %       tt = ic.TreeTable();
    %       tt.Columns = [
    %           ic.table.TextColumn("Name", Width=250, Sortable=true)
    %           ic.table.NumberColumn("Size", Sortable=true)
    %           ic.table.TextColumn("Type", Filterable=true)
    %       ];
    %       tt.ExpanderColumn = "Name";
    %
    %       root = ic.tree.Node("Documents", Icon="folder");
    %       reports = root.add("Reports", Icon="folder");
    %       reports.add("Q1.pdf", Icon="file-text", ...
    %           Data=struct('Size', 1024, 'Type', "PDF"));
    %       reports.add("Q2.pdf", Icon="file-text", ...
    %           Data=struct('Size', 2048, 'Type', "PDF"));
    %       tt.Items = root;

    properties (SetObservable, Description = "Reactive")
        % > COLUMNS column definitions
        Columns ic.table.Column = ic.table.Column.empty
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > EXPANDERCOLUMN field name of the column with tree indentation ("" = first)
        ExpanderColumn (1,1) string = ""

        % > SELECTABLE whether nodes can be selected
        Selectable (1,1) logical = true

        % > SIZE row density
        Size (1,1) string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % > HEIGHT height of the container (number for px, or CSS string)
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400

        % > SHOWLINE whether to display tree connector lines
        ShowLine (1,1) logical = true

        % > STRIPED whether to show alternating row colors
        Striped (1,1) logical = false

        % > LAZYLOAD when true, children only render when parent is expanded
        LazyLoad (1,1) logical = true

        % > SORTFIELD currently sorted column field ("" = no sort)
        SortField (1,1) string = ""

        % > SORTDIRECTION sort direction
        SortDirection (1,1) string {mustBeMember(SortDirection, ...
            ["none", "asc", "desc"])} = "none"

        % > FILTERS active column filters (field → filterValue)
        Filters (1,1) struct = struct()
    end

    properties (SetObservable, Description = "Reactive")
        % > LEAFCONTEXTMENU context menu entries for leaf nodes
        LeafContextMenu ic.menu.Entry = ic.menu.Entry.empty
        % > FOLDERCONTEXTMENU context menu entries for folder nodes
        FolderContextMenu ic.menu.Entry = ic.menu.Entry.empty
    end

    properties (Access = private, Hidden, Transient)
        ItemsListener event.listener
    end

    events (Description = "Reactive")
        % > SORTCHANGED fires when the user clicks a sortable column header
        SortChanged

        % > FILTERCHANGED fires when the user changes a column filter
        FilterChanged

        % > CELLCLICKED fires when the user clicks a leaf cell
        CellClicked
    end

    events
        % > CELLEDITED fires when the user edits a cell value inline
        CellEdited

        % > COLUMNRESIZED fires when the user finishes resizing a column
        ColumnResized
    end

    methods
        function this = TreeTable(props)
            arguments
                props.?ic.TreeTable
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TreeBase(props);

            % Auto-infer columns when Items is set and Columns is empty
            this.ItemsListener = addlistener(this, 'Items', 'PostSet', ...
                @(~, ~) this.autoInferColumns());

            % Subscribe to view events
            this.subscribe('cellEdited', ...
                @(comp, ~, data) comp.handleCellEdited(data));
            this.subscribe('columnResized', ...
                @(comp, ~, data) comp.handleColumnResized(data));
            this.subscribe('cellAction', ...
                @(comp, ~, data) comp.dispatchCellAction(data));
        end

        function delete(this)
            delete(this.ItemsListener);
        end

        function set.SortField(this, val)
            if val ~= this.SortField
                this.setValueSilently('SortDirection', 'asc');
            end
            this.SortField = val;
        end
    end

    methods (Access = protected)
        function autoInferColumns(this)
            % Auto-infer columns from first leaf's Data when Columns is empty.
            if ~isempty(this.Columns) || isempty(this.Items), return; end
            leaf = findFirstLeaf(this.Items);
            if ~isempty(leaf) && ~isempty(leaf.Data)
                this.Columns = ic.table.Column.fromStruct(leaf.Data);
            end
        end

        function handleCellEdited(this, data)
            % Update Node.Data or Node.Label and fire CellEdited event.
            key = string(data.key);
            field = string(data.field);
            newValue = data.newValue;
            oldValue = data.oldValue;

            node = this.Items.resolve(key);

            % Determine effective expander column
            if this.ExpanderColumn ~= ""
                expander = this.ExpanderColumn;
            elseif ~isempty(this.Columns)
                expander = this.Columns(1).Field;
            else
                expander = "";
            end

            if field == expander
                % Edit the node label
                node.Label = string(newValue);
            else
                % Edit node data field
                s = node.Data;
                % Coerce value via column definition
                cols = this.Columns;
                colIdx = find(arrayfun(@(c) c.Field == field, cols), 1);
                if ~isempty(colIdx)
                    colDef = cols(colIdx);
                    if isfield(s, char(field))
                        newValue = colDef.coerceEditValue(newValue, s.(field));
                    else
                        newValue = colDef.coerceEditValue(newValue, []);
                    end
                end
                s.(field) = newValue;
                node.Data = s;
            end

            notify(this, 'CellEdited', ic.event.MEvent(struct( ...
                'key', key, ...
                'field', field, ...
                'oldValue', oldValue, ...
                'newValue', newValue)));
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
            node = this.Items.resolve(string(data.key));
            col.OnCellAction(col, node, data.data);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the tree table container
            out = this.publish("focus", []);
        end

        function out = editCell(this, node, field, value)
            % > EDITCELL Programmatically edit a leaf cell
            arguments
                this
                node (1,1) ic.tree.Node
                field (1,1) string
                value
            end
            key = this.Items.keyOf(node);
            assert(~isempty(key), "ic:TreeTable:NodeNotInTree", ...
                "Node '%s' is not in the Items tree.", node.Label);

            % Determine effective expander column
            if this.ExpanderColumn ~= ""
                expander = this.ExpanderColumn;
            elseif ~isempty(this.Columns)
                expander = this.Columns(1).Field;
            else
                expander = "";
            end

            oldValue = [];
            if field == expander
                oldValue = node.Label;
                node.Label = string(value);
            else
                s = node.Data;
                if isfield(s, char(field))
                    oldValue = s.(field);
                end
                s.(field) = value;
                node.Data = s;
            end

            out = this.publish("editCell", struct( ...
                'key', char(key), ...
                'field', char(field), ...
                'value', value));

            notify(this, 'CellEdited', ic.event.MEvent(struct( ...
                'key', key, ...
                'field', field, ...
                'oldValue', oldValue, ...
                'newValue', value)));
        end
    end
end

function leaf = findFirstLeaf(nodes)
    % Find the first leaf node (no children) in a tree.
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
