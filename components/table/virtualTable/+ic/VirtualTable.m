classdef VirtualTable < ic.TableBase & ic.mixin.Requestable
    % virtual-scrolling table for large datasets.
    % Only visible rows exist in the DOM (~30-40 elements). The frontend fetches rows on demand via the request/response protocol. Sorting and filtering are performed server-side in MATLAB via the column's filterColumn and sortKey methods.

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % total number of rows in the current view (after filtering)
        RowCount (1,1) double = 0

        % cache-buster counter incremented on every recompute. The frontend clears its row cache when this changes
        ViewVersion (1,1) double = 0
    end

    properties
        % the full dataset as a MATLAB table. Its not reactive and never published to the frontend. The view fetches slices on demand as the user scrolls and interacts with the table
        Data table = table()
    end

    properties (Hidden)
        % print request info to the command window for debugging
        Verbose logical = false
    end

    properties (Access = private)
        % sorted + filtered row indices into Data
        ViewIndices double = []

        % guard flag: when true, set.Data skips selection clear + recompute
        InCellEdit logical = false

        % PostSet listener handles
        ViewListeners event.listener
    end

    methods
        function this = VirtualTable(props)
            arguments
                props.?ic.VirtualTable
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TableBase(props);

            % register request handler for row fetching
            this.onRequest("getRows", @(comp, data) comp.handleGetRows(data));

            % recompute view when sort/filter state changes
            this.ViewListeners = [
                addlistener(this, 'SortField', 'PostSet', ...
                    @(~,~) this.recomputeView())
                addlistener(this, 'SortDirection', 'PostSet', ...
                    @(~,~) this.recomputeView())
                addlistener(this, 'Filters', 'PostSet', ...
                    @(~,~) this.recomputeView())
            ];

            % initial view computation
            this.recomputeView();
        end

        function delete(this)
            delete(this.ViewListeners);
        end

        function set.Data(this, val)
            if ~this.InCellEdit %#ok<MCSUP>
                % clear selection when data changes
                this.Selection = struct('type', 'none', 'value', []);
                % auto-infer columns if empty
                if isempty(this.Columns) && ~isempty(val) && height(val) > 0
                    this.setValueSilently('Columns', ic.table.Column.fromTable(val));
                end
            end
            this.Data = val;
            if ~this.InCellEdit %#ok<MCSUP>
                this.recomputeView();
            end
        end
    end

    methods (Access = protected)
        function handleCellEdited(this, evtData)
            % update Data when a cell is edited in the view, then conditionally recompute
            field = string(evtData.field);
            rowIndex = double(evtData.rowIndex) + 1;
            newValue = evtData.newValue;
            oldValue = evtData.oldValue;

            colIdx = find(arrayfun(@(c) c.Field == field, this.Columns), 1);
            colDef = this.Columns(colIdx);
            colData = this.Data.(char(field));
            newValue = colDef.coerceEditValue(newValue, colData);

            % read old value from Data (proper MATLAB type) before overwrite
            if iscell(colData)
                oldMatlabVal = colData{rowIndex};
            else
                oldMatlabVal = colData(rowIndex);
            end

            % modify cell: guard prevents set.Data from recomputing
            this.InCellEdit = true;
            if iscell(colData)
                this.Data.(char(field)){rowIndex} = newValue;
            else
                this.Data.(char(field))(rowIndex) = newValue;
            end
            this.InCellEdit = false;

            % only recompute if the edit impacts sorting or filtering
            needsRecompute = false;

            % sort: if this column is being sorted, row position may change
            if this.SortField == field && this.SortDirection ~= "none"
                needsRecompute = true;
            end

            % filter: if this column is being filtered, check pass/fail
            if ~needsRecompute
                fk = char(field);
                fStruct = this.Filters;
                if isfield(fStruct, fk)
                    fv = fStruct.(fk);
                    if ~isempty(fv)
                        oldPass = this.testFilter(colDef, oldMatlabVal, fv);
                        newPass = this.testFilter(colDef, newValue, fv);
                        if oldPass ~= newPass
                            needsRecompute = true;
                        end
                    end
                end
            end

            if needsRecompute
                this.recomputeView();
            end

            % fire MATLAB event
            notify(this, 'CellEdited', ic.event.MEvent(struct( ...
                'field', field, ...
                'rowIndex', rowIndex, ...
                'oldValue', oldValue, ...
                'newValue', newValue)));
        end
    end

    methods (Description = "Reactive")
        function out = removeRow(this, rowIndex)
            % remove a row by its  index
            arguments
                this
                % row index to remove
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
            end
            assert(rowIndex <= height(this.Data), "ic:VirtualTable:RowOutOfRange", ...
                "Row index %d exceeds table height %d.", rowIndex, height(this.Data));

            data = this.Data;
            data(rowIndex, :) = [];
            this.Data = data;
            out = [];
        end

        function out = removeColumn(this, field)
            % remove a column by field name
            arguments
                this
                % field name of the column to remove
                field (1,1) string
            end
            assert(ismember(field, this.Data.Properties.VariableNames), ...
                "ic:VirtualTable:FieldNotFound", ...
                "Field '%s' does not exist in Data.", field);

            data = removevars(this.Data, field);
            this.Data = data;

            % update Columns
            cols = this.Columns;
            idx = find(arrayfun(@(c) c.Field == field, cols), 1);
            if ~isempty(idx)
                cols(idx) = [];
                this.Columns = cols;
            end
            out = [];
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
            assert(rowIndex <= height(this.Data), "ic:VirtualTable:RowOutOfRange", ...
                "Row index %d exceeds table height %d.", rowIndex, height(this.Data));
            assert(ismember(field, this.Data.Properties.VariableNames), ...
                "ic:VirtualTable:FieldNotFound", ...
                "Field '%s' does not exist in Data.", field);

            data = this.Data;
            data{rowIndex, field} = value;
            this.Data = data;
            out = [];
        end

        function out = refresh(this)
            % manually force to recompute the view
            this.recomputeView();
            out = [];
        end
    end

    methods (Access = private)
        function tf = testFilter(~, colDef, value, filterValue)
            % check if a single scalar value passes a filter
            if isstruct(filterValue) && isfield(filterValue, 'isEmpty')
                if isstring(value) || ischar(value)
                    tf = ismissing(string(value)) || string(value) == "";
                else
                    tf = ismissing(value);
                end
                return
            end
            if isstruct(filterValue) && isfield(filterValue, 'isNotEmpty')
                if isstring(value) || ischar(value)
                    tf = ~ismissing(string(value)) && string(value) ~= "";
                else
                    tf = ~ismissing(value);
                end
                return
            end
            % delegate to column's filterColumn (works on scalars)
            tf = colDef.filterColumn(value, filterValue);
        end

        function recomputeView(this)
            % rebuild sorted + filtered index array
            nRows = height(this.Data);
            if nRows == 0
                this.ViewIndices = [];
                this.RowCount = 0;
                this.ViewVersion = this.ViewVersion + 1;
                return;
            end

            indices = (1:nRows)';

            % apply filters
            filters = this.Filters;
            filterFields = fieldnames(filters);
            for k = 1:numel(filterFields)
                field = string(filterFields{k});
                filterValue = filters.(filterFields{k});
                if isempty(filterValue), continue; end

                % find column definition
                colIdx = find(arrayfun(@(c) c.Field == field, this.Columns), 1);
                if isempty(colIdx), continue; end
                col = this.Columns(colIdx);

                % isEmpty checks
                if isstruct(filterValue) && isfield(filterValue, 'isEmpty')
                    colData = this.Data.(char(field));
                    sliced = colData(indices);
                    if isstring(sliced) || iscellstr(sliced)
                        mask = ismissing(sliced) | (string(sliced) == "");
                    else
                        mask = ismissing(sliced);
                    end
                    indices = indices(mask);
                    continue;
                end

                % isNotEmpty checks
                if isstruct(filterValue) && isfield(filterValue, 'isNotEmpty')
                    colData = this.Data.(char(field));
                    sliced = colData(indices);
                    if isstring(sliced) || iscellstr(sliced)
                        mask = ~ismissing(sliced) & (string(sliced) ~= "");
                    else
                        mask = ~ismissing(sliced);
                    end
                    indices = indices(mask);
                    continue;
                end

                % type-specific filter
                colData = this.Data.(char(field));
                mask = col.filterColumn(colData(indices), filterValue);
                indices = indices(mask);
            end

            % sorting
            if this.SortField ~= "" && this.SortDirection ~= "none"
                colIdx = find(arrayfun(@(c) c.Field == this.SortField, ...
                    this.Columns), 1);
                if ~isempty(colIdx)
                    col = this.Columns(colIdx);
                    colData = this.Data.(char(this.SortField));
                    keys = col.sortKey(colData(indices));

                    % handle NaN: push to end regardless of direction
                    isNan = false(numel(keys), 1);
                    if isnumeric(keys)
                        isNan = isnan(keys);
                    end

                    if this.SortDirection == "asc"
                        [~, order] = sort(keys(~isNan), 'ascend');
                    else
                        [~, order] = sort(keys(~isNan), 'descend');
                    end
                    nonNanIndices = indices(~isNan);
                    nanIndices = indices(isNan);
                    indices = [nonNanIndices(order); nanIndices];
                end
            end

            this.ViewIndices = indices;
            this.RowCount = numel(indices);
            this.ViewVersion = this.ViewVersion + 1;

            if this.Verbose
                fprintf("[VirtualTable] recomputeView → %d of %d rows\n", ...
                    numel(indices), nRows);
            end
        end

        function result = handleGetRows(this, data)
            % return a chunk of rows from the current view
            offset = double(data.offset);
            count = double(data.count);
            viewLen = numel(this.ViewIndices);

            startIdx = offset + 1;
            if startIdx > viewLen
                result = struct('rows', {{}}, 'indices', []);
                return;
            end
            endIdx = min(offset + count, viewLen);
            viewSlice = this.ViewIndices(startIdx:endIdx);

            % extract sub-table and convert to struct array
            subTable = this.Data(viewSlice, :);
            rows = table2struct(subTable);

            result = struct();
            result.rows = rows;
            result.indices = viewSlice;  % 1-based original indices

            if this.Verbose
                fprintf("[VirtualTable] getRows offset=%d count=%d → %d row(s)\n", ...
                    offset, count, numel(viewSlice));
            end
        end
    end
end
