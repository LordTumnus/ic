classdef Table < ic.TableBase
    % > TABLE Flat data table with rich column types.
    %
    %   Displays tabular data from a MATLAB table with sortable/filterable
    %   columns. Supports text, number, badge, sparkline, progress, boolean,
    %   button, link, icon, and avatar cell renderers.
    %
    %   Example:
    %       t = ic.Table();
    %       t.Data = table(["Alice";"Bob"], [30;25], ...
    %           'VariableNames', ["Name","Age"]);
    %       t.Columns = [
    %           ic.table.Column("Name", Sortable=true)
    %           ic.table.Column("Age", Type="number", Sortable=true)
    %       ];
    %       t.Striped = true;
    %       addlistener(t, 'RowClicked', @(~,e) disp(e.Data));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > DATA the table data (MATLAB table)
        Data table = table()
    end

    methods
        function this = Table(props)
            arguments
                props.?ic.Table
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TableBase(props);
        end

        function set.Data(this, val)
            % Clear selection when data changes
            this.setValueSilently('Selection', struct('type', 'none', 'value', []));
            % auto-infer columns if empty
            if isempty(this.Columns) && ~isempty(val) && height(val) > 0
                this.setValueSilently('Columns', ic.table.Column.fromTable(val));
            end
            this.Data = val;
        end
    end

    methods (Description = "Reactive")
        function out = removeRow(this, rowIndex)
            % > REMOVEROW Remove a row by 1-based index
            arguments
                this
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
            end
            assert(rowIndex <= height(this.Data), "ic:Table:RowOutOfRange", ...
                "Row index %d exceeds table height %d.", rowIndex, height(this.Data));

            % save selection
            savedSel = this.Selection;

            % remove row silently
            data = this.Data;
            data(rowIndex, :) = [];
            this.setValueSilently('Data', data);

            % adjust selection by type
            switch savedSel.type
                case 'row'
                    vals = savedSel.value;
                    vals(vals == rowIndex) = [];
                    vals(vals > rowIndex) = vals(vals > rowIndex) - 1;
                    if isempty(vals)
                        savedSel = struct('type', 'none', 'value', []);
                    else
                        savedSel.value = vals;
                    end
                case 'cell'
                    cells = savedSel.value;
                    keep = [cells.row] ~= rowIndex;
                    cells = cells(keep);
                    for i = 1:numel(cells)
                        if cells(i).row > rowIndex
                            cells(i).row = cells(i).row - 1;
                        end
                    end
                    if isempty(cells)
                        savedSel = struct('type', 'none', 'value', []);
                    else
                        savedSel.value = cells;
                    end
            end
            this.setValueSilently('Selection', savedSel);

            out = this.publish("removeRow", struct('index', rowIndex - 1));
        end

        function out = removeColumn(this, field)
            % > REMOVECOLUMN Remove a column by field name
            arguments
                this
                field (1,1) string
            end
            assert(ismember(field, this.Data.Properties.VariableNames), ...
                "ic:Table:FieldNotFound", ...
                "Field '%s' does not exist in Data.", field);

            % save selection
            savedSel = this.Selection;

            % remove from Data silently
            data = removevars(this.Data, field);
            this.setValueSilently('Data', data);

            % adjust selection by type
            switch savedSel.type
                case 'column'
                    vals = string(savedSel.value);
                    vals(vals == field) = [];
                    if isempty(vals)
                        savedSel = struct('type', 'none', 'value', []);
                    else
                        savedSel.value = vals;
                    end
                case 'cell'
                    cells = savedSel.value;
                    keep = ~strcmp({cells.field}, char(field));
                    cells = cells(keep);
                    if isempty(cells)
                        savedSel = struct('type', 'none', 'value', []);
                    else
                        savedSel.value = cells;
                    end
            end
            this.setValueSilently('Selection', savedSel);

            % publish event to view
            out = this.publish("removeColumn", struct('field', char(field)));

            cols = this.Columns;
            idx = find(arrayfun(@(c) c.Field == field, cols), 1);
            if ~isempty(idx)
                cols(idx) = [];
                this.Columns = cols;
            end
        end

        function out = editCell(this, rowIndex, field, value)
            % > EDITCELL Update a single cell
            arguments
                this
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
                field (1,1) string
                value
            end
            assert(rowIndex <= height(this.Data), "ic:Table:RowOutOfRange", ...
                "Row index %d exceeds table height %d.", rowIndex, height(this.Data));
            assert(ismember(field, this.Data.Properties.VariableNames), ...
                "ic:Table:FieldNotFound", ...
                "Field '%s' does not exist in Data.", field);

            % save selection
            savedSel = this.Selection;

            % modify cell silently
            data = this.Data;
            data{rowIndex, field} = value;
            this.setValueSilently('Data', data);

            % restore selection
            this.setValueSilently('Selection', savedSel);

            out = this.publish("editCell", struct( ...
                'rowIndex', rowIndex - 1, ...
                'field', char(field), ...
                'value', value));
        end
    end
end
