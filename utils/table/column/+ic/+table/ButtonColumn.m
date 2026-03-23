classdef ButtonColumn < ic.table.Column
    % interactive button column that renders one or more clickable buttons per cell. Button clicks are routed to the column's OnCellAction callback.

    properties
        % array of #ic.table.CellButton definitions rendered in each cell
        Buttons ic.table.CellButton = ic.table.CellButton.empty
    end

    methods
        function this = ButtonColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.ButtonColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("button", opts);
            % action columns are never sortable or filterable
            this.Sortable = false;
            this.Filterable = false;
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if ~isempty(this.Buttons)
                cfg.buttons = this.Buttons.toStruct();
            end
        end
    end
end
