classdef Table < ic.TableBase
    % flat data table with rich column types.
    % Suitable for small-to-medium datasets (up to ~5000 rows). For larger datasets, use #ic.VirtualTable which virtualizes scrolling and performs server-side sort/filter.
    % {note} Avoid modifying the #ic.Table.Data property directly for large tables, as it triggers a full re-render. Instead, use the #ic.Table.editCell, #ic.Table.removeRow, and #ic.Table.removeColumn methods which update the data more efficiently and preserve selection state. {/note}

    properties (SetObservable, AbortSet, Description = "Reactive")
        % the table data as a MATLAB table. Columns are auto-inferred on first assignment if #ic.TableBase.Columns is empty
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
            % clear selection when data changes
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
            % remove a row
            arguments
                this
                % row index to remove
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
            % remove a column by field name
            arguments
                this
                % field name of the column to remove
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
            % update a single cell value programmatically
            arguments
                this
                % row index
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
                % column field name
                field (1,1) string
                % new cell value
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
