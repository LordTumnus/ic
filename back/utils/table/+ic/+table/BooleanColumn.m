classdef BooleanColumn < ic.table.Column
    % > BOOLEANCOLUMN Boolean column definition.
    %
    %   Displays cell values as a checkbox, text, or numeric indicator.
    %
    %   Example:
    %       c = ic.table.BooleanColumn("Active", Sortable=true, Width=75)
    %       c = ic.table.BooleanColumn("Active", DisplayMode="text")

    properties
        % > DISPLAYMODE visual representation: "checkbox", "text", or "numeric"
        DisplayMode (1,1) string {mustBeMember(DisplayMode, ...
            ["checkbox", "text", "numeric"])} = "checkbox"

        % > COLORRULES conditional background color rules (first match wins)
        %   Evaluates true=1, false=0 against the rules.
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

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
        function cfg = buildConfig(this)
            cfg = struct('displayMode', this.DisplayMode);
            if ~isempty(this.ColorRules)
                cfg.colorRules = this.ColorRules.toStruct();
            end
        end
    end
end
