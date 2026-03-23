classdef ColorRule
    % conditional color rule for table columns.
    % Defines a comparison condition that is evaluated for all the cells in the column. When the condition is met, the specified color is applied.
    % When multiple rules are defined on a column (as an array of #ic.table.ColorRule), the first successful rule for a specific cell wins (early return)

    properties
        % comparison operator
        Operator (1,1) string {mustBeMember(Operator, ...
            [">", ">=", "<", "<=", "==", "~=", "between"])} = ">"

        % threshold value. Scalar for most operators, or [lo hi] for "between"
        Value = 0

        % hex color string applied when the condition matches
        Color (1,1) string = ""
    end

    methods
        function this = ColorRule(op, val, color)
            % construct a color rule.
            % {example}
            %   rules = [
            %       ic.table.ColorRule(">",  90, "#4ade80")
            %       ic.table.ColorRule("<",  50, "#f87171")
            %       ic.table.ColorRule("between", [60 80], "#facc15")
            %   ];
            % {/example}
            arguments
                % comparison operator
                op    (1,1) string = ">"
                % threshold value (scalar or [lo hi] for "between")
                val = 0
                % hex color string
                color (1,1) string = ""
            end
            this.Operator = op;
            this.Value    = val;
            this.Color    = color;
        end

        function s = toStruct(this)
            n = numel(this);
            if n == 0
                s = struct('op',{},'value',{},'color',{});
                return;
            end
            e = cell(1, n);
            s = struct('op',e,'value',e,'color',e);
            for i = 1:n
                s(i).op    = this(i).Operator;
                s(i).value = this(i).Value;
                s(i).color = this(i).Color;
            end
        end
    end
end
