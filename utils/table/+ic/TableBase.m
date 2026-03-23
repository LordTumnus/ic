classdef (Abstract) TableBase < ic.core.Component & ic.mixin.HasContextMenu
    % abstract base for table components.
    % Provides shared column configuration, sorting, filtering, row selection, and cell interaction for #ic.Table and #ic.VirtualTable
    % {superclass}
    % #ic.mixin.HasContextMenu
    % {/superclass}

    properties (SetObservable, Description = "Reactive")
        % column definitions that control how each data field is displayed, sorted, and filtered
        Columns ic.table.Column = ic.table.Column.empty
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether all table interactions are disabled
        Disabled (1,1) logical = false

        % dimension of the table rows and text relative to the component font size
        Size (1,1) string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % height of the table, in pixels or as a CSS string
        Height {ic.check.CssValidators.mustBeSize(Height)} = "auto"

        % whether rows, columns, and cells can be selected by clicking on them (rows can only be selected if #ic.TableBase.ShowRowNumbers is true)
        Selectable (1,1) logical = false

        % whether to show a row number column on the left edge
        ShowRowNumbers (1,1) logical = false

        % whether to alternate row background colors for readability
        Striped (1,1) logical = false

        % field name of the currently sorted column ("" means no sort active)
        SortField (1,1) string = ""

        % direction of the current sort
        SortDirection (1,1) string {mustBeMember(SortDirection, ...
            ["none", "asc", "desc"])} = "none"

        % current selection state as a struct with fields 'type' ("none", "row", "column", or "cell") and 'value'
        Selection (1,1) struct = struct('type', 'none', 'value', [])

        % active column filters as a struct mapping field names to filter values
        Filters (1,1) struct = struct()
    end

    events (Description = "Reactive")
        % fires when the user changes the selection (row, column, or cell click)
        % {payload}
        % selection | struct: struct with fields 'type' (char) and 'value'
        % {/payload}
        SelectionChanged

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
        % filters | struct: full filters state after the change
        % {/payload}
        FilterChanged

        % fires when the user clicks any cell
        % {payload}
        % field | char: column field name
        % rowIndex | double: row index
        % value | any: cell value
        % rowData | struct: full row data
        % {/payload}
        CellClicked

        % fires when the user clicks any row
        % {payload}
        % rowIndex | double: row index
        % rowData | struct: full row data
        % {/payload}
        RowClicked

        % fires when the user clicks a column header
        % {payload}
        % field | char: field name of the clicked column
        % column | struct: column definition
        % {/payload}
        ColumnClicked
    end

    events
        % fires when the user finishes resizing a column
        % {payload}
        % field | char: field name of the resized column
        % width | double: new column width in pixels
        % {/payload}
        ColumnResized

        % fires when the user edits a cell value inline (non-reactive, dispatched from MATLAB)
        % {payload}
        % field | char: field name of the edited column
        % rowIndex | double: row index
        % oldValue | any: previous cell value
        % newValue | any: new cell value after editing
        % {/payload}
        CellEdited
    end

    methods
        function this = TableBase(props)
            this@ic.core.Component(props);
            this.subscribe('cellAction', ...
                @(comp, ~, data) comp.dispatchCellAction(data));
            this.subscribe('cellEdited', ...
                @(comp, ~, data) comp.handleCellEdited(data));
            this.subscribe('columnResized', ...
                @(comp, ~, data) comp.handleColumnResized(data));
        end

        function set.Selection(this, val)
            mustBeMember(val.type, {'none', 'row', 'column', 'cell'});
            this.Selection = val;
        end

        function set.SortField(this, val)
            if val ~= this.SortField
                this.setValueSilently('SortDirection', 'asc');
            end
            this.SortField = val;
        end
    end

    methods (Access = protected)
        function dispatchCellAction(this, data)
            % route a cell action to the column's OnCellAction callback
            field = string(data.field);
            cols = this.Columns;
            idx = find(arrayfun(@(c) c.Field == field, cols), 1);
            if isempty(idx), return; end

            col = cols(idx);
            if isempty(col.OnCellAction), return; end

            % convert 0-based row index from view to 1-based
            rowIndex = double(data.rowIndex) + 1;
            col.OnCellAction(col, rowIndex, data.data);
        end

        function handleColumnResized(this, data)
            % update column Width and fire ColumnResized event
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

        function handleCellEdited(this, data)
            % update Data silently and fire CellEdited event
            field = string(data.field);
            rowIndex = double(data.rowIndex) + 1;  % 0-based → 1-based
            newValue = data.newValue;
            oldValue = data.oldValue;

            % copy data to avoid republishing to the view
            data = this.Data;

            colIdx = find(arrayfun(@(c) c.Field == field, this.Columns), 1);
            colDef = this.Columns(colIdx);
            colData = data.(field);
            newValue = colDef.coerceEditValue(newValue, colData);

            if iscell(colData)
                data.(field){rowIndex} = newValue;
            else
                data.(field)(rowIndex) = newValue;
            end
            this.setValueSilently('Data', data);

            % fire MATLAB event for user listeners
            notify(this, 'CellEdited', ic.event.MEvent(struct( ...
                'field', field, ...
                'rowIndex', rowIndex, ...
                'oldValue', oldValue, ...
                'newValue', newValue)));
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the table container
            out = this.publish("focus", []);
        end

        function out = clearSelection(this)
            % clear the current selection
            this.setValueSilently('Selection', struct('type', 'none', 'value', []));
            out = this.publish("clearSelection", []);
        end

        function out = scrollToRow(this, rowKey)
            % scroll to a specific row by key.
            arguments
                this
                % value of the row key field to scroll to
                % For #ic.Table and #ic.VirtualTable, pass a row index.
                % For #ic.TreeTable and #ic.VirtualTreeTable, pass the positional key string
                rowKey (1,1) string
            end
            out = this.publish("scrollToRow", struct('key', rowKey));
        end

        function out = focusCell(this, rowIndex, field)
            % scroll to and focus a specific cell
            arguments
                this
                % row index
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
                % column field name
                field (1,1) string
            end
            out = this.publish("focusCell", struct( ...
                'rowIndex', rowIndex - 1, 'field', char(field)));
        end
    end
end
