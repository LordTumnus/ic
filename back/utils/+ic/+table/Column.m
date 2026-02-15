classdef Column
    % > COLUMN Definition of a single table column.
    %
    %   Specifies how a column of data is displayed, including its
    %   header text, cell renderer type, width, sort/filter behavior,
    %   alignment, and type-specific configuration.
    %
    %   Example:
    %       c = ic.table.Column("Name", Width=200, Sortable=true)
    %       c = ic.table.Column("Age", Type="number", Align="right")
    %       c = ic.table.Column("Status", Type="badge", Filterable=true, ...
    %           Config=struct('colorMap', struct('Active','success')))
    %       c = ic.table.Column("Trend", Type="sparkline", ...
    %           Config=struct('type',"line",'color',"primary",'height',20))

    properties
        % > FIELD data field name (table variable or struct field)
        Field (1,1) string

        % > HEADER display text in the column header (defaults to Field)
        Header (1,1) string = ""

        % > TYPE cell renderer type
        Type (1,1) string {mustBeMember(Type, [ ...
            "text", "number", "badge", "sparkline", "progress", ...
            "boolean", "button", "link", "icon", "avatar" ...
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

        % > FORMAT printf format string for number display (e.g. "$%.2f")
        Format (1,1) string = ""

        % > CONFIG type-specific configuration struct
        %   badge:     colorMap (struct: value → variant name)
        %   sparkline: type ("line"|"bar"), color (variant), height (px)
        %   progress:  variant (color variant name)
        %   button:    label (string), variant, fill ("solid"|"outline"|"ghost")
        %   avatar:    textField (companion data field), radius (px)
        Config (1,1) struct = struct()
    end

    methods
        function this = Column(field, opts)
            % > COLUMN Construct a column definition.
            %   c = ic.table.Column("name")
            %   c = ic.table.Column("age", Type="number", Sortable=true)
            arguments
                field (1,1) string
                opts.?ic.table.Column
            end
            this.Field = field;
            flds = fieldnames(opts);
            for i = 1:numel(flds)
                this.(flds{i}) = opts.(flds{i});
            end
            if this.Header == ""
                this.Header = field;
            end
        end

        function s = toStruct(this)
            % > TOSTRUCT Convert column array to struct array for JSON.
            n = numel(this);
            if n == 0
                s = struct('field', {}, 'header', {}, 'type', {}, ...
                    'width', {}, 'minWidth', {}, 'sortable', {}, ...
                    'filterable', {}, 'resizable', {}, 'align', {}, ...
                    'pinned', {}, 'format', {}, 'config', {});
                return;
            end
            s = repmat(struct(), 1, n);
            for i = 1:n
                c = this(i);
                s(i).field = c.Field;
                s(i).header = c.Header;
                s(i).type = c.Type;
                s(i).width = c.Width;
                s(i).minWidth = c.MinWidth;
                s(i).sortable = c.Sortable;
                s(i).filterable = c.Filterable;
                s(i).resizable = c.Resizable;
                s(i).align = c.Align;
                s(i).pinned = c.Pinned;
                s(i).format = c.Format;
                s(i).config = c.Config;
            end
        end

        function json = jsonencode(this, varargin)
            % > JSONENCODE Serialize to JSON via struct conversion.
            json = jsonencode(this.toStruct(), varargin{:});
        end
    end

    methods (Static)
        function cols = fromTable(t)
            % > FROMTABLE Auto-infer columns from a MATLAB table.
            %   cols = ic.table.Column.fromTable(myTable)
            arguments
                t table
            end
            varNames = t.Properties.VariableNames;
            n = numel(varNames);
            cols = ic.table.Column.empty(0, n);
            for i = 1:n
                vn = string(varNames{i});
                col = t.(varNames{i});
                if isnumeric(col)
                    tp = "number";
                elseif islogical(col)
                    tp = "boolean";
                else
                    tp = "text";
                end
                cols(i) = ic.table.Column(vn, Type=tp);
            end
        end

        function cols = fromStruct(s)
            % > FROMSTRUCT Auto-infer columns from a struct's field names.
            %   cols = ic.table.Column.fromStruct(struct('name',"A",'age',30))
            arguments
                s (1,1) struct
            end
            fields = fieldnames(s);
            n = numel(fields);
            cols = ic.table.Column.empty(0, n);
            for i = 1:n
                cols(i) = ic.table.Column(string(fields{i}));
            end
        end
    end
end
