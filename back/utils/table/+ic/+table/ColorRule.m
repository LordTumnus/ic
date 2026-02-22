classdef ColorRule < matlab.mixin.SetGetExactNames
    % > COLORRULE Conditional color rule for number columns.
    %
    %   Defines a condition and a color to apply when the condition is met.
    %   First matching rule wins.
    %
    %   Example:
    %       rules = [
    %           ic.table.ColorRule(">",  90, "#4ade80")   % green
    %           ic.table.ColorRule("<",  50, "#f87171")   % red
    %           ic.table.ColorRule("between", [60 80], "#facc15")
    %       ];

    properties
        % > OPERATOR comparison operator
        Operator (1,1) string {mustBeMember(Operator, ...
            [">", ">=", "<", "<=", "==", "~=", "between"])} = ">"

        % > VALUE threshold (scalar, or [lo hi] for "between")
        Value double = 0

        % > COLOR hex color string, e.g. "#4ade80"
        Color (1,1) string = ""
    end

    methods
        function this = ColorRule(op, val, color)
            arguments
                op    (1,1) string = ">"
                val   double       = 0
                color (1,1) string = ""
            end
            this.Operator = op;
            this.Value    = val;
            this.Color    = color;
        end

        function s = toStruct(this)
            % > TOSTRUCT Convert array to struct array for JSON.
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
