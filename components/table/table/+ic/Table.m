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
            % remove one or more rows by index.
            % Multiple indices can be passed to batch removals into a
            % single message to the view.
            % {example}
            %   tbl.removeRow(3)
            %   tbl.removeRow(1, 4, 7)
            % {/example}
            arguments (Input)
                this
            end
            arguments (Input, Repeating)
                % row index (1-based)
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
            end

            nRemoves = numel(rowIndex);
            % collect and sort descending so earlier indices stay valid
            indices = zeros(1, nRemoves);
            for k = 1:nRemoves
                indices(k) = rowIndex{k};
            end
            indices = unique(indices, 'sorted');

            data = this.Data;
            for k = 1:numel(indices)
                assert(indices(k) <= height(data), "ic:Table:RowOutOfRange", ...
                    "Row index %d exceeds table height %d.", indices(k), height(data));
            end

            savedSel = this.Selection;

            % remove rows (descending order to preserve indices)
            removes = cell(1, numel(indices));
            for k = numel(indices):-1:1
                idx = indices(k);
                data(idx, :) = [];
                removes{k} = struct('index', idx - 1);

                % adjust selection
                switch savedSel.type
                    case 'row'
                        vals = savedSel.value;
                        vals(vals == idx) = [];
                        vals(vals > idx) = vals(vals > idx) - 1;
                        if isempty(vals)
                            savedSel = struct('type', 'none', 'value', []);
                        else
                            savedSel.value = vals;
                        end
                    case 'cell'
                        cells = savedSel.value;
                        keep = [cells.row] ~= idx;
                        cells = cells(keep);
                        for i = 1:numel(cells)
                            if cells(i).row > idx
                                cells(i).row = cells(i).row - 1;
                            end
                        end
                        if isempty(cells)
                            savedSel = struct('type', 'none', 'value', []);
                        else
                            savedSel.value = cells;
                        end
                end
            end

            this.setValueSilently('Data', data);
            this.setValueSilently('Selection', savedSel);

            out = this.publish("removeRow", removes);
        end

        function out = removeColumn(this, field)
            % remove one or more columns by field name.
            % Multiple field names can be passed to batch removals into a
            % single message to the view.
            % {example}
            %   tbl.removeColumn("Price")
            %   tbl.removeColumn("Price", "Volume", "Sector")
            % {/example}
            arguments (Input)
                this
            end
            arguments (Input, Repeating)
                % field name of the column to remove
                field (1,1) string
            end

            nRemoves = numel(field);
            removes = cell(1, nRemoves);
            savedSel = this.Selection;
            data = this.Data;

            for k = 1:nRemoves
                f = field{k};
                assert(ismember(f, data.Properties.VariableNames), ...
                    "ic:Table:FieldNotFound", ...
                    "Field '%s' does not exist in Data.", f);

                data = removevars(data, f);
                removes{k} = struct('field', char(f));

                % adjust selection
                switch savedSel.type
                    case 'column'
                        vals = string(savedSel.value);
                        vals(vals == f) = [];
                        if isempty(vals)
                            savedSel = struct('type', 'none', 'value', []);
                        else
                            savedSel.value = vals;
                        end
                    case 'cell'
                        cells = savedSel.value;
                        keep = ~strcmp({cells.field}, char(f));
                        cells = cells(keep);
                        if isempty(cells)
                            savedSel = struct('type', 'none', 'value', []);
                        else
                            savedSel.value = cells;
                        end
                end
            end

            this.setValueSilently('Data', data);
            this.setValueSilently('Selection', savedSel);

            out = this.publish("removeColumn", removes);

            % remove from Columns definition
            cols = this.Columns;
            for k = 1:nRemoves
                idx = find(arrayfun(@(c) c.Field == field{k}, cols), 1);
                if ~isempty(idx)
                    cols(idx) = [];
                end
            end
            this.Columns = cols;
        end

        function out = editCell(this, rowIndex, field, value)
            % update one or more cell values programmatically.
            % Multiple edits can be batched into a single message to the
            % view by passing repeating (rowIndex, field, value) triplets.
            % {example}
            %   tbl.editCell(1, "Price", 42.5)
            %   tbl.editCell(1, "Price", 42.5, 2, "Price", 99.0, 3, "Name", "Foo")
            % {/example}
            arguments (Input)
                this
            end
            arguments (Input, Repeating)
                % row index (1-based)
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
                % column field name
                field (1,1) string
                % new cell value
                value
            end

            nEdits = numel(rowIndex);
            edits = cell(1, nEdits);

            % save selection once
            savedSel = this.Selection;
            data = this.Data;

            for k = 1:nEdits
                assert(rowIndex{k} <= height(data), "ic:Table:RowOutOfRange", ...
                    "Row index %d exceeds table height %d.", rowIndex{k}, height(data));
                assert(ismember(field{k}, data.Properties.VariableNames), ...
                    "ic:Table:FieldNotFound", ...
                    "Field '%s' does not exist in Data.", field{k});

                if iscell(data.(field{k}))
                    data.(field{k}){rowIndex{k}} = value{k};
                else
                    data{rowIndex{k}, field{k}} = value{k};
                end
                edits{k} = struct( ...
                    'rowIndex', rowIndex{k} - 1, ...
                    'field', char(field{k}), ...
                    'value', value{k});
            end

            % commit all changes silently as a single update
            this.setValueSilently('Data', data);
            this.setValueSilently('Selection', savedSel);

            out = this.publish("editCell", edits);
        end
    end
end
