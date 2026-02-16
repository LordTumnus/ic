classdef SparklineColumn < ic.table.Column
    % > SPARKLINECOLUMN Inline sparkline chart column definition.
    %
    %   Displays cell values (numeric arrays) as tiny line or bar charts.
    %
    %   Example:
    %       c = ic.table.SparklineColumn("Trend", Height=24, Color="success")
    %       c = ic.table.SparklineColumn("Histogram", ChartType="bar")

    properties
        % > CHARTTYPE sparkline chart type ("line" or "bar")
        ChartType (1,1) string {mustBeMember(ChartType, ["line","bar"])} = "line"

        % > COLOR color variant name for the chart
        Color (1,1) string = "primary"

        % > HEIGHT chart height in pixels
        Height (1,1) double {mustBePositive} = 20
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
            if this.ChartType ~= "line",  cfg.type   = this.ChartType; end
            if this.Color ~= "primary",   cfg.color  = this.Color;     end
            if this.Height ~= 20,         cfg.height = this.Height;    end
        end
    end
end
