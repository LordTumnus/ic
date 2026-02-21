classdef BooleanColumn < ic.table.Column
    % > BOOLEANCOLUMN Boolean column definition.
    %
    %   Displays cell values as check / cross icons.
    %
    %   Example:
    %       c = ic.table.BooleanColumn("Active", Sortable=true, Width=75)

    methods
        function this = BooleanColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.BooleanColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("boolean", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(~)
            cfg = struct();
        end
    end
end
