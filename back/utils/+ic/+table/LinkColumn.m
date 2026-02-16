classdef LinkColumn < ic.table.Column
    % > LINKCOLUMN Clickable link column definition.
    %
    %   Displays cell values as underlined links that fire CellAction.
    %
    %   Example:
    %       c = ic.table.LinkColumn("Website", Width=200)

    methods
        function this = LinkColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.LinkColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("link", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(~)
            cfg = struct();
        end
    end
end
