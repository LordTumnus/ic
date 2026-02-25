classdef VirtualTable < ic.TableBase & ic.mixin.Requestable
    % > VIRTUALTABLE Virtual-scrolling table for massive datasets.
    %
    %   Renders a table with virtual scrolling and on-demand row fetching.
    %   Only visible rows exist in the DOM (~30-40 elements). Sorting and
    %   filtering are performed server-side in MATLAB, not in the browser.
    %
    %   Example:
    %       vt = ic.VirtualTable();
    %       vt.Data = array2table(rand(100000, 3), ...
    %           'VariableNames', ["A","B","C"]);
    %       vt.Columns = [
    %           ic.table.NumberColumn("A", Sortable=true, Filterable=true)
    %           ic.table.NumberColumn("B", Sortable=true)
    %           ic.table.NumberColumn("C", Filterable=true)
    %       ];

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % > ROWCOUNT total number of rows in the current view (after filtering)
        RowCount (1,1) double = 0

        % > VIEWVERSION cache-buster counter — Svelte clears its row cache
        %   whenever this value changes (incremented on every recompute)
        ViewVersion (1,1) double = 0
    end

    properties
        % > DATA the full dataset (NOT reactive — never published to Svelte)
        Data table = table()
    end

    properties (Hidden)
        % > VERBOSE print request info to the command window
        Verbose logical = false
    end

    properties (Access = private)
        % Sorted + filtered 1-based row indices into Data
        ViewIndices double = []
    end

    methods
        function this = VirtualTable(props)
            arguments
                props.?ic.VirtualTable
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TableBase(props);

            % Register request handler for row fetching
            this.onRequest("getRows", @(comp, data) comp.handleGetRows(data));

            % Recompute view when sort/filter state changes
            addlistener(this, 'SortField', 'PostSet', ...
                @(~,~) this.recomputeView());
            addlistener(this, 'SortDirection', 'PostSet', ...
                @(~,~) this.recomputeView());
            addlistener(this, 'Filters', 'PostSet', ...
                @(~,~) this.recomputeView());

            % Initial view computation
            this.recomputeView();
        end

        function set.Data(this, val)
            % Clear selection when data changes
            this.setValueSilently('Selection', struct('type', 'none', 'value', []));
            % Auto-infer columns if empty
            if isempty(this.Columns) && ~isempty(val) && height(val) > 0
                this.setValueSilently('Columns', ic.table.Column.fromTable(val));
            end
            this.Data = val;
            this.recomputeView();
        end
    end

    methods (Access = protected)
        function handleCellEdited(this, evtData)
            % > HANDLECELLEDITED modifies the contents of the Data when a
            % cell gets edited in the view. Since the edit might impact
            % sorting/filtering, we need to recompute view.
            field = string(evtData.field);
            rowIndex = double(evtData.rowIndex) + 1;
            newValue = evtData.newValue;
            oldValue = evtData.oldValue;

            colDef = this.Columns(strcmp({this.Columns.Field}, char(field)));
            colData = this.Data.(char(field));
            newValue = colDef.coerceEditValue(newValue, colData);

            % modify cell in internal data
            if iscell(colData)
                this.Data.(char(field)){rowIndex} = newValue;
            else
                this.Data.(char(field))(rowIndex) = newValue;
            end
            this.recomputeView();

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
            % > REMOVEROW Remove a row by 1-based original index.
            arguments
                this
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
            % > REMOVECOLUMN Remove a column by field name.
            arguments
                this
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
            % > EDITCELL Update a single cell by 1-based original index.
            arguments
                this
                rowIndex (1,1) double {mustBePositive, mustBeInteger}
                field (1,1) string
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
            % > REFRESH Manually recompute the view.
            this.recomputeView();
            out = [];
        end
    end

    methods (Access = private)
        function recomputeView(this)
            % > RECOMPUTEVIEW Rebuild sorted + filtered index array.
            nRows = height(this.Data);
            if nRows == 0
                this.ViewIndices = [];
                this.setValueSilently('RowCount', 0);
                this.setValueSilently('ViewVersion', this.ViewVersion + 1);
                return;
            end

            indices = (1:nRows)';

            % apply filters (empty/notempty and column filters)
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

                %isNotEmpty checks
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
            this.setValueSilently('RowCount', numel(indices));
            this.setValueSilently('ViewVersion', this.ViewVersion + 1);

            if this.Verbose
                fprintf("[VirtualTable] recomputeView → %d of %d rows\n", ...
                    numel(indices), nRows);
            end
        end

        function result = handleGetRows(this, data)
            % > HANDLEGETROWS Return a chunk of rows from the current view.
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
