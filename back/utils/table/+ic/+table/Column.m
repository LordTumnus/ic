classdef Column < matlab.mixin.SetGetExactNames & ...
                  matlab.mixin.Heterogeneous
    % > COLUMN Definition of a single table column.
    %
    %   Specifies how a column of data is displayed, including its
    %   header text, cell renderer type, width, sort/filter behavior,
    %   alignment, and type-specific configuration.

    properties
        % > FIELD data field name (table variable or struct field)
        Field (1,1) string

        % > HEADER display text in the column header (defaults to Field)
        Header (1,1) string = ""

        % > TYPE cell renderer type
        Type (1,1) string {mustBeMember(Type, [ ...
            "text", "number", "boolean", "progressbar", "sparkline", "image" ...
            ])} = "text"

        % > WIDTH column width — number for px, or string for CSS (e.g. "20%")
        Width = ""

        % > MINWIDTH minimum column width in px (0 = no minimum)
        MinWidth (1,1) double {mustBeNonnegative} = 0

        % > SORTABLE whether clicking the header sorts by this column
        Sortable (1,1) logical = false

        % > FILTERABLE whether the header shows a filter button
        Filterable (1,1) logical = false

        % > RESIZABLE whether the column can be resized by dragging
        Resizable (1,1) logical = true

        % > ALIGN cell text alignment ("auto" infers from Type)
        Align (1,1) string {mustBeMember(Align, [ ...
            "left", "center", "right", "auto" ...
            ])} = "auto"

        % > PINNED pin column to left or right edge
        Pinned (1,1) string {mustBeMember(Pinned, [ ...
            "none", "left", "right" ...
            ])} = "none"

        % > CONFIG type-specific configuration struct (use typed subclasses instead)
        Config (1,1) struct = struct()

        % > ONCELLACTION callback: @(column, rowIndex, data)
        OnCellAction function_handle = function_handle.empty
    end

    methods
        function this = Column(field, opts)
            % > COLUMN Construct a column definition.
            %   c = ic.table.Column("name")
            %   c = ic.table.Column("age", Type="number", Sortable=true)
            arguments
                field (1,1) string = ""
                opts.?ic.table.Column
            end
            this.Field = field;
            if ~isempty(fieldnames(opts))
                set(this, opts);
            end
            if this.Header == ""
                this.Header = field;
            end
        end
    end

    methods (Sealed)
        function s = toStruct(this)
            % > TOSTRUCT Convert column array to struct array for JSON.
            n = numel(this);
            if n == 0
                s = struct('field',{},'header',{},'type',{}, ...
                    'width',{},'minWidth',{},'sortable',{}, ...
                    'filterable',{},'resizable',{},'align',{}, ...
                    'pinned',{},'hasAction',{},'config',{});
                return;
            end
            e = cell(1, n);
            s = struct('field',e,'header',e,'type',e, ...
                'width',e,'minWidth',e,'sortable',e, ...
                'filterable',e,'resizable',e,'align',e, ...
                'pinned',e,'hasAction',e,'config',e);
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
                s(i).hasAction  = ~isempty(c.OnCellAction);
                s(i).config     = c.buildConfig();
            end
        end

        function json = jsonencode(this, varargin)
            % > JSONENCODE Serialize to JSON via struct conversion.
            json = jsonencode(this.toStruct(), varargin{:});
        end
    end

    methods (Access = protected)
        function initFromOpts(this, type, opts)
            % > INITFROMOPTS Set common + type-specific properties, lock Type.
            %   Filters out Type and Config (managed internally by subclasses),
            %   then applies all remaining name-value pairs via set().
            opts = rmfield(opts, ...
                intersect(fieldnames(opts), {'Type','Config'}));
            if ~isempty(fieldnames(opts))
                set(this, opts);
            end
            this.Type = type;
            if this.Header == ""
                this.Header = this.Field;
            end
        end

        function cfg = buildConfig(this)
            % > BUILDCONFIG Return type-specific config struct for JSON.
            %   Base class returns raw Config property (backward compat).
            %   Subclasses override to construct config from named properties.
            cfg = this.Config;
        end
    end

    methods (Static, Sealed, Access = protected)
        function obj = getDefaultScalarElement()
            obj = ic.table.Column();
        end
    end

    methods (Static)
        function cols = fromTable(t)
            % > FROMTABLE Auto-infer typed columns from a MATLAB table.
            %   cols = ic.table.Column.fromTable(myTable)
            arguments
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
                else
                    colCell{i} = ic.table.TextColumn(vn);
                end
            end
            cols = [colCell{:}];
        end

        function cols = fromStruct(s)
            % > FROMSTRUCT Auto-infer columns from a struct's field names.
            %   cols = ic.table.Column.fromStruct(struct('name',"A",'age',30))
            arguments
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
