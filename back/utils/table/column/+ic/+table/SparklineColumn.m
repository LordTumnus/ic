classdef SparklineColumn < ic.table.Column
    % > SPARKLINECOLUMN Sparkline column definition.
    %
    %   Displays cell values (numeric arrays) as inline mini line charts.
    %   Y-axis auto-scales to the data range per cell.
    %
    %   Metric controls what ColorRules, ShowLabel, and filtering operate on:
    %     "total"    — the last absolute value in the array (default)
    %     "relative" — the percentage change from first to last value
    %
    %   Cell data must be a numeric vector (row or column) per row.
    %   Use a cell column in the MATLAB table to store variable-length arrays.
    %
    %   Example:
    %       c = ic.table.SparklineColumn("trend", ...
    %               Metric="relative", ShowLabel=true, FillArea=true, ...
    %               ColorRules=[
    %                   ic.table.ColorRule(">=", 5, "#22c55e")
    %                   ic.table.ColorRule("<=", -5, "#ef4444")
    %               ])

    properties
        % > LINEWIDTH stroke width in px
        LineWidth (1,1) double {mustBePositive} = 1.5

        % > FILLAREA fill the area under the line
        FillArea (1,1) logical = false

        % > SHOWENDDOT show a dot at the last data point
        ShowEndDot (1,1) logical = true

        % > SHOWLABEL show metric value beside the sparkline
        ShowLabel (1,1) logical = false

        % > METRIC what ColorRules, label, and filter operate on
        Metric (1,1) string {mustBeMember(Metric, [ ...
            "total", "relative" ...
            ])} = "total"

        % > VARIANT line color variant
        Variant (1,1) string {mustBeMember(Variant, [ ...
            "primary", "secondary", "success", "warning", "destructive" ...
            ])} = "primary"

        % > COLORRULES conditional color rules evaluated against the metric
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = SparklineColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.SparklineColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("sparkline", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.LineWidth ~= 1.5,          cfg.lineWidth = this.LineWidth;       end
            if this.FillArea,                   cfg.fillArea = true;                 end
            if ~this.ShowEndDot,                cfg.showEndDot = false;              end
            if this.ShowLabel,                  cfg.showLabel = true;                end
            if this.Metric ~= "total",          cfg.metric = this.Metric;            end
            if this.Variant ~= "primary",       cfg.variant = this.Variant;          end
            if ~isempty(this.ColorRules)
                cfg.colorRules = this.ColorRules.toStruct();
            end
        end
    end
end
