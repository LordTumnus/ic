classdef SparklineColumn < ic.table.Column
    % inline sparkline (mini line chart) column for numeric array data.
    % Cell data must be a numeric vector per row.

    properties
        % stroke width of the line, in pixels
        LineWidth (1,1) double {mustBePositive} = 1.5

        % whether to fill the area under the line
        FillArea (1,1) logical = false

        % whether to show a dot at the last data point
        ShowEndDot (1,1) logical = true

        % whether to show the metric value beside the sparkline
        ShowLabel (1,1) logical = false

        % metric that the rest of the properties operate on. "total" uses the last value; "relative" uses the percentage change from first to last
        Metric (1,1) string {mustBeMember(Metric, [ ...
            "total", "relative" ...
            ])} = "total"

        % line color variant
        Variant (1,1) string {mustBeMember(Variant, [ ...
            "primary", "secondary", "success", "warning", "destructive" ...
            ])} = "primary"

        % conditional color rules evaluated against the metric value
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = SparklineColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.SparklineColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("sparkline", opts);
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

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(this, columnData, filterValue)
            % extract metric value per row, then range check
            values = this.extractMetric(columnData);
            mask = true(numel(values), 1);
            if isfield(filterValue, 'min') && ~isempty(filterValue.min)
                mask = mask & (values >= filterValue.min);
            end
            if isfield(filterValue, 'max') && ~isempty(filterValue.max)
                mask = mask & (values <= filterValue.max);
            end
        end

        function keys = sortKey(this, columnData)
            % sort by metric value
            keys = this.extractMetric(columnData);
        end
    end

    methods (Access = private)
        function values = extractMetric(this, columnData)
            % extract the metric value from each sparkline cell
            n = numel(columnData);
            values = nan(n, 1);
            for i = 1:n
                arr = columnData{i};
                if isempty(arr), continue; end
                if this.Metric == "relative" && numel(arr) >= 2
                    first = arr(1);
                    if first ~= 0
                        values(i) = ((arr(end) - first) / abs(first)) * 100;
                    end
                else
                    values(i) = arr(end);
                end
            end
        end
    end
end
