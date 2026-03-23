classdef BooleanColumn < ic.table.Column
    % boolean column that displays logical values as checkboxes, text, or numeric indicators.

    properties
        % visual representation of the boolean value
        DisplayMode (1,1) string {mustBeMember(DisplayMode, ...
            ["checkbox", "text", "numeric"])} = "checkbox"

        % conditional background color rules. Evaluates true=1, false=0 against the rules
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = BooleanColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.BooleanColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("boolean", opts);
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

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % exact match: filterValue is a logical scalar
            mask = logical(columnData) == logical(filterValue);
        end
    end
end
