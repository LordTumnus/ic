classdef TreeTable < ic.TreeBase & ic.mixin.HasContextMenu
    % hierarchical tree with aligned table columns.
    % Folder nodes render as full-width expand/collapse rows; leaf nodes render per-column cells
    properties (SetObservable, Description = "Reactive")
        % column definitions that control how each data field is displayed, sorted, and filtered
        Columns ic.table.Column = ic.table.Column.empty
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % field name of the column with tree indentation ("" = first)
        ExpanderColumn (1,1) string = ""

        % whether nodes can be selected
        Selectable (1,1) logical = true

        % size of the tree table relative to its font size
        Size (1,1) string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % height of the container, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400

        % whether to display tree connector lines
        ShowLine (1,1) logical = true

        % whether to show alternating row colors
        Striped (1,1) logical = false

        % when true, children only render when their parent is expanded
        LazyLoad (1,1) logical = true

        % currently sorted column field ("" = no sort)
        SortField (1,1) string = ""

        % sort direction
        SortDirection (1,1) string {mustBeMember(SortDirection, ...
            ["none", "asc", "desc"])} = "none"

        % active column filters
        Filters (1,1) struct = struct()
    end

    properties (SetObservable, Description = "Reactive")
        % context menu entries for leaf nodes
        LeafContextMenu ic.menu.Entry = ic.menu.Entry.empty

        % context menu entries for folder nodes
        FolderContextMenu ic.menu.Entry = ic.menu.Entry.empty
    end

    properties (Access = private, Hidden, Transient)
        ItemsListener event.listener
    end

    events (Description = "Reactive")
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
        function this = TreeTable(props)
            arguments
                props.?ic.TreeTable
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TreeBase(props);

            % auto-infer columns when Items is set and Columns is empty
            this.ItemsListener = addlistener(this, 'Items', 'PostSet', ...
                @(~, ~) this.autoInferColumns());

            % subscribe to view events
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
            % auto-infer columns from first leaf's Data when Columns is empty.
            if ~isempty(this.Columns) || isempty(this.Items), return; end
            leaf = findFirstLeaf(this.Items);
            if ~isempty(leaf) && ~isempty(leaf.Data)
                this.Columns = ic.table.Column.fromStruct(leaf.Data);
            end
        end

        function handleCellEdited(this, data)
            % update Node.Data or Node.Label and fire CellEdited event.
            key = string(data.key);
            field = string(data.field);
            newValue = data.newValue;
            oldValue = data.oldValue;

            node = this.Items.resolve(key);

            % determine effective expander column
            if this.ExpanderColumn ~= ""
                expander = this.ExpanderColumn;
            elseif ~isempty(this.Columns)
                expander = this.Columns(1).Field;
            else
                expander = "";
            end

            if field == expander
                % edit the node label
                node.Label = string(newValue);
            else
                % edit node data field
                s = node.Data;
                % coerce value via column definition
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
            % programmatically focus the tree table container
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("focus", []);
        end

        function out = editCell(this, node, field, value)
            % programmatically edit a leaf cell
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            arguments
                this
                % the node of the cell to edit
                node (1,1) ic.tree.Node
                % the field name of the column to edit
                field (1,1) string
                % the new value to set (type depends on column definition)
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
