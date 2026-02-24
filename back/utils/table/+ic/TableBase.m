classdef (Abstract) TableBase < ic.core.Component
    % > TABLEBASE Abstract base for table components.
    %
    %   Provides shared column configuration, sorting state, row selection,
    %   and common events/methods for Table and TreeTable.
    %
    %   Subclasses: ic.Table, ic.TreeTable

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > COLUMNS column definitions
        Columns ic.table.Column = ic.table.Column.empty

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
    end

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % > VALUE selected row keys (hidden from user — use Selection)
        Value = []

        % > FILTERS active column filters (field → filterValue)
        Filters (1,1) struct = struct()
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the user changes the selection
        ValueChanged

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

    methods
        function this = TableBase(props)
            this@ic.core.Component(props);
            this.subscribe('cellAction', ...
                @(comp, ~, data) comp.dispatchCellAction(data));
        end

        function set.SortField(this, val)
            % Reset direction when field changes
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

            % Convert 0-based row index from Svelte to 1-based
            rowIndex = double(data.rowIndex) + 1;
            col.OnCellAction(col, rowIndex, data.data);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the table container
            out = this.publish("focus", []);
        end

        function out = clearSelection(this)
            % > CLEARSELECTION clear all selected rows
            this.Value = [];
            out = this.publish("clearSelection", []);
        end

        function out = scrollToRow(this, rowKey)
            % > SCROLLTOROW scroll to a specific row by key
            %   t.scrollToRow(5)       % flat table — row index
            %   t.scrollToRow("1-3")   % tree table — positional key
            out = this.publish("scrollToRow", struct('key', rowKey));
        end
    end
end
