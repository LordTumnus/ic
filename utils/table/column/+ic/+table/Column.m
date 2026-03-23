classdef Column < matlab.mixin.Heterogeneous & ...
                  ic.event.TransportData
    % definition of a single table column.
    % Specifies how a data field is displayed, including its header text, cell renderer, width, sort/filter behavior, alignment, and type-specific configuration

    properties
        % data field name (table variable name or struct field name) that this column reads from
        Field (1,1) string

        % display text in the column header. Defaults to #ic.table.Column.Field if empty
        Header (1,1) string = ""

        % cell renderer type that determines how values are displayed
        Type (1,1) string {mustBeMember(Type, [ ...
            "text", "number", "boolean", "progressbar", "sparkline", ...
            "image", "enum", "rating", "date", "button", "color" ...
            ])} = "text"

        % column width, in pixels or as a CSS string. If empty, width is automatic based on content.
        Width = ""

        % minimum column width in pixels (0 = no minimum)
        MinWidth (1,1) double {mustBeNonnegative} = 0

        % whether clicking the header sorts the table by this column
        Sortable (1,1) logical = false

        % whether the header shows a filter button
        Filterable (1,1) logical = false

        % whether the column can be resized by dragging one of its header edges
        Resizable (1,1) logical = true

        % cell text alignment. "auto" infers from the column Type (e.g. numbers align right)
        Align (1,1) string {mustBeMember(Align, [ ...
            "left", "center", "right", "auto" ...
            ])} = "auto"

        % pin the column to the left or right edge of the table, so that it remains visible when horizontally scrolling
        Pinned (1,1) string {mustBeMember(Pinned, [ ...
            "none", "left", "right" ...
            ])} = "none"

        % whether this column is visible
        Visible (1,1) logical = true

        % whether cells in this column can be edited inline by double-clicking
        Editable (1,1) logical = false

        % type-specific configuration struct. Prefer using typed subclasses instead of setting this directly
        Config (1,1) struct = struct()

        % callback invoked when a cell action is triggered. The callback signature should be @(column, rowIndex, data) callback(column, rowIndex, data)
        OnCellAction function_handle = function_handle.empty

        % context menu entries shown on right-click in this column's cells
        ContextMenu ic.menu.Entry = ic.menu.Entry.empty
    end

    methods
        function this = Column(field, opts)
            arguments
                field (1,1) string = ""
                opts.?ic.table.Column
            end
            this.Field = field;
            fns = fieldnames(opts);
            for i = 1:numel(fns)
                this.(fns{i}) = opts.(fns{i});
            end
            if this.Header == ""
                this.Header = field;
            end
        end
    end

    methods (Sealed)
        function s = toStruct(this)
            n = numel(this);
            if n == 0
                s = struct('field',{},'header',{},'type',{}, ...
                    'width',{},'minWidth',{},'sortable',{}, ...
                    'filterable',{},'resizable',{},'align',{}, ...
                    'pinned',{},'visible',{},'editable',{}, ...
                    'hasAction',{},'config',{},'contextMenu',{});
                return;
            end
            e = cell(1, n);
            s = struct('field',e,'header',e,'type',e, ...
                'width',e,'minWidth',e,'sortable',e, ...
                'filterable',e,'resizable',e,'align',e, ...
                'pinned',e,'visible',e,'editable',e, ...
                'hasAction',e,'config',e,'contextMenu',e);
            for i = 1:n
                c = this(i);
                s(i).field      = c.Field;
                s(i).header     = c.Header;
                s(i).type       = c.Type;
                s(i).width      = c.Width;
                s(i).minWidth   = c.MinWidth;
                s(i).sortable   = c.Sortable;
                s(i).filterable = c.Filterable;
                s(i).resizable  = c.Resizable;
                s(i).align      = c.Align;
                s(i).pinned     = c.Pinned;
                s(i).visible    = c.Visible;
                s(i).editable   = c.Editable;
                s(i).hasAction  = ~isempty(c.OnCellAction);
                s(i).config     = c.buildConfig();
                cm = c.ContextMenu;
                if isempty(cm)
                    s(i).contextMenu = [];
                else
                    cells = cell(1, numel(cm));
                    for j = 1:numel(cm), cells{j} = cm(j).toStruct(); end
                    s(i).contextMenu = cells;
                end
            end
        end

        function json = jsonencode(this, varargin)
            json = jsonencode(this.toStruct(), varargin{:});
        end
    end

    methods (Access = protected)
        function this = initFromOpts(this, type, opts)
            % set common + type-specific properties, lock Type.
            % Used by typed subclass constructors
            opts = rmfield(opts, ...
                intersect(fieldnames(opts), {'Type','Config'}));
            fns = fieldnames(opts);
            for i = 1:numel(fns)
                this.(fns{i}) = opts.(fns{i});
            end
            this.Type = type;
            if this.Header == ""
                this.Header = this.Field;
            end
        end

        function cfg = buildConfig(this)
            % return type-specific config struct for JSON.
            % Subclasses override to construct config from named properties
            cfg = this.Config;
        end
    end

    methods (Access={?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function val = coerceEditValue(~, rawValue, colData)
            % convert a raw JSON edit value to the column's MATLAB type.
            % Subclasses override for type-specific conversions (e.g. datetime)
            val = rawValue;
            if ischar(val), val = string(val); end
            if iscategorical(colData)
                val = categorical(val);
            end
        end

        function mask = filterColumn(~, columnData, ~)
            % server-side filter: return logical mask over the column data.
            % Base returns all-true (unsupported column type). Subclasses override for type-specific logic
            mask = true(numel(columnData), 1);
        end

        function keys = sortKey(~, columnData)
            % server-side sort key extraction.
            % Returns a vector suitable for MATLAB's sort(). Subclasses override when sort order differs from natural order
            keys = columnData;
        end
    end

    methods (Static, Sealed, Access = protected)
        function obj = getDefaultScalarElement()
            obj = ic.table.Column();
        end
    end

    methods (Static)
        function cols = fromTable(t)
            % auto-infer typed columns from a MATLAB table.
            % {returns} an array of #ic.table.Column objects with Field set to the table variable names, and Type inferred from the variable data type {/returns}
            % {example}
            %   cols = ic.table.Column.fromTable(myTable);
            % {/example}
            arguments
                % table from which to infer columns
                t table
            end
            varNames = t.Properties.VariableNames;
            n = numel(varNames);
            if n == 0
                cols = ic.table.Column.empty;
                return;
            end
            colCell = cell(1, n);
            for i = 1:n
                vn = string(varNames{i});
                col = t.(varNames{i});
                if isnumeric(col)
                    colCell{i} = ic.table.NumberColumn(vn);
                elseif islogical(col)
                    colCell{i} = ic.table.BooleanColumn(vn);
                elseif isdatetime(col)
                    colCell{i} = ic.table.DateColumn(vn);
                else
                    colCell{i} = ic.table.TextColumn(vn);
                end
            end
            cols = [colCell{:}];
        end

        function cols = fromStruct(s)
            % auto-infer text columns from a struct's field names.
            % {example}
            %   cols = ic.table.Column.fromStruct(struct('name', "A", 'age', 30));
            % {/example}
            arguments
                % struct from which to infer columns
                s (1,1) struct
            end
            fields = fieldnames(s);
            n = numel(fields);
            if n == 0
                cols = ic.table.Column.empty;
                return;
            end
            colCell = cell(1, n);
            for i = 1:n
                colCell{i} = ic.table.TextColumn(string(fields{i}));
            end
            cols = [colCell{:}];
        end
    end
end
