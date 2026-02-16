classdef ButtonColumn < ic.table.Column
    % > BUTTONCOLUMN Clickable button column definition.
    %
    %   Displays a button in each cell that fires CellAction on click.
    %
    %   Example:
    %       c = ic.table.ButtonColumn("Action", Label="Edit", Fill="ghost")
    %       c = ic.table.ButtonColumn("Delete", Variant="destructive", Fill="solid")

    properties
        % > LABEL button text (empty = show cell value)
        Label (1,1) string = ""

        % > VARIANT button color variant
        Variant (1,1) string {mustBeMember(Variant, [ ...
            "primary","secondary","destructive" ...
            ])} = "primary"

        % > FILL button fill style
        Fill (1,1) string {mustBeMember(Fill, [ ...
            "solid","outline","ghost" ...
            ])} = "outline"
    end

    methods
        function this = ButtonColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.ButtonColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("button", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.Label ~= "",           cfg.label   = this.Label;   end
            if this.Variant ~= "primary",  cfg.variant = this.Variant; end
            if this.Fill ~= "outline",     cfg.fill    = this.Fill;    end
        end
    end
end
