classdef ButtonColumn < ic.table.Column
    % > BUTTONCOLUMN Interactive button(s) column for table rows.
    %
    %   Renders one or more clickable buttons per cell. If the data
    %   contains a value for this column's field, the text is shown
    %   alongside the buttons.
    %
    %   Sorting and filtering are disabled by design.
    %
    %   Example:
    %       c = ic.table.ButtonColumn("Actions", Buttons=[
    %           ic.table.CellButton("edit",   Label="Edit",   Icon="pencil")
    %           ic.table.CellButton("delete", Icon="trash-2", Variant="destructive")
    %       ], OnCellAction=@(col, row, data) disp(data.action))

    properties
        % > BUTTONS array of button definitions
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
            % Action columns are never sortable or filterable
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
