classdef IconColumn < ic.table.Column
    % > ICONCOLUMN Icon column definition.
    %
    %   Displays cell values as Lucide icons (value = icon name).
    %
    %   Example:
    %       c = ic.table.IconColumn("StatusIcon", Width=50, Align="center")

    methods
        function this = IconColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.IconColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("icon", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(~)
            cfg = struct();
        end
    end
end
