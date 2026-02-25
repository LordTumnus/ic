classdef (Abstract) TableBase < ic.core.Component & ic.mixin.HasContextMenu
    % > TABLEBASE Abstract base for table components.
    %
    %   Provides shared column configuration, sorting state, row selection,
    %   and common events/methods for Table and TreeTable.

    properties (SetObservable, Description = "Reactive")
        % > COLUMNS column definitions
        Columns ic.table.Column = ic.table.Column.empty
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > DISABLED whether the control is disabled
        Disabled (1,1) logical = false

        % > SIZE size of the control
        Size (1,1) string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % > HEIGHT height of the table (number for px, or CSS string like "100%")
        Height {ic.check.CssValidators.mustBeSize(Height)} = "auto"

        % > SELECTABLE whether rows, columns, and cells can be selected
        Selectable (1,1) logical = false

        % > SHOWROWNUMBERS whether to show a row number column
        ShowRowNumbers (1,1) logical = false

        % > STRIPED whether to show alternating row colors
        Striped (1,1) logical = false

        % > SORTFIELD currently sorted column field ("" = no sort)
        SortField (1,1) string = ""

        % > SORTDIRECTION sort direction
        SortDirection (1,1) string {mustBeMember(SortDirection, ...
            ["none", "asc", "desc"])} = "none"

        % > SELECTION current selection state (struct with .type and .value)
        Selection (1,1) struct = struct('type', 'none', 'value', [])

        % > FILTERS active column filters (field → filterValue)
        Filters (1,1) struct = struct()
    end

    events (Description = "Reactive")
        % > SELECTIONCHANGED fires when the user changes the selection
        SelectionChanged

        % > SORTCHANGED fires when the user clicks a sortable column header
        SortChanged

        % > FILTERCHANGED fires when the user changes a column filter
        FilterChanged

        % > CELLCLICKED fires when the user clicks any cell
        CellClicked

        % > ROWCLICKED fires when the user clicks any row
        RowClicked

        % > COLUMNCLICKED fires when the user clicks a column header
        ColumnClicked

    end

    events
        % > COLUMNRESIZED fires when the user finishes resizing a column
        ColumnResized

        % > CELLEDITED fires when the user edits a cell value inline
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
            % > DISPATCHCELLACTION route a cell action to the column's callback.
            field = string(data.field);
            cols = this.Columns;
            idx = find(arrayfun(@(c) c.Field == field, cols), 1);
            if isempty(idx), return; end

            col = cols(idx);
            if isempty(col.OnCellAction), return; end

            % Convert 0-based row index from view to 1-based
            rowIndex = double(data.rowIndex) + 1;
            col.OnCellAction(col, rowIndex, data.data);
        end

        function handleColumnResized(this, data)
            % > HANDLECOLUMNRESIZED update column Width and fire event.
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
            % > HANDLECELLEDITED update Data silently and fire CellEdited event.
            field = string(data.field);
            rowIndex = double(data.rowIndex) + 1;  % 0-based → 1-based
            newValue = data.newValue;
            oldValue = data.oldValue;

            % copy data to avoid republishing to the view
            data = this.Data;

            colDef = this.Columns(strcmp({this.Columns.Field}, field));
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
            % > FOCUS programmatically focus the table container
            out = this.publish("focus", []);
        end

        function out = clearSelection(this)
            % > CLEARSELECTION clear the current selection
            this.setValueSilently('Selection', struct('type', 'none', 'value', []));
            out = this.publish("clearSelection", []);
        end

        function out = scrollToRow(this, rowKey)
            % > SCROLLTOROW scroll to a specific row by key
            %   t.scrollToRow(5)       % flat table — row index
            %   t.scrollToRow("1-3")   % tree table — positional key
            out = this.publish("scrollToRow", struct('key', rowKey));
        end

        function out = focusCell(this, rowIndex, field)
            % > FOCUSCELL scroll to and focus a specific cell
            %   t.focusCell(3, "Name")
            arguments
                this
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
                field (1,1) string
            end
            out = this.publish("focusCell", struct( ...
                'rowIndex', rowIndex - 1, 'field', char(field)));
        end
    end
end
