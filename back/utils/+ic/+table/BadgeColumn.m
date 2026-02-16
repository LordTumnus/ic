classdef BadgeColumn < ic.table.Column
    % > BADGECOLUMN Badge/tag column definition.
    %
    %   Displays cell values as colored badge pills. Map values to
    %   variant names via ColorMap.
    %
    %   Example:
    %       c = ic.table.BadgeColumn("Status", Filterable=true, ...
    %           ColorMap=struct('Active','success','Inactive','secondary'))

    properties
        % > COLORMAP mapping of cell values to color variants
        %   Struct where field names are cell values and values are variant
        %   names: "primary", "secondary", "success", "warning", "destructive"
        ColorMap (1,1) struct = struct()
    end

    methods
        function this = BadgeColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.BadgeColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("badge", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if ~isempty(fieldnames(this.ColorMap))
                cfg.colorMap = this.ColorMap;
            end
        end
    end
end
