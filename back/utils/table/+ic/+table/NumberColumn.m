classdef NumberColumn < ic.table.Column
    % > NUMBERCOLUMN Numeric column definition.
    %
    %   Displays cell values as formatted numbers. Use the inherited
    %   Format property for printf-style formatting (e.g. "$%.2f").
    %
    %   Example:
    %       c = ic.table.NumberColumn("Age", Sortable=true, Align="right")
    %       c = ic.table.NumberColumn("Price", Format="$%.2f", Width=100)

    methods
        function this = NumberColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.NumberColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("number", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(~)
            cfg = struct();
        end
    end
end
