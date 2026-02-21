classdef TextColumn < ic.table.Column
    % > TEXTCOLUMN Plain text column definition.
    %
    %   Displays cell values as text with optional truncation.
    %
    %   Example:
    %       c = ic.table.TextColumn("Name", Sortable=true, Width=200)

    methods
        function this = TextColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.TextColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("text", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(~)
            cfg = struct();
        end
    end
end
