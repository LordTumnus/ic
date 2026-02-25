classdef ProgressBarColumn < ic.table.Column
    % > PROGRESSBARCOLUMN Progress-bar column definition.
    %
    %   Displays cell values as an inline progress bar with optional label.
    %   Supports variant colors, conditional bar coloring via ColorRules,
    %   and sprintf-style label formatting.
    %
    %   Example:
    %       c = ic.table.ProgressBarColumn("completion", Max=100, ...
    %               ShowLabel=true, Variant="success")
    %       c = ic.table.ProgressBarColumn("score", ...
    %               ColorRules=[
    %                   ic.table.ColorRule(">=", 80, "#4ade80")
    %                   ic.table.ColorRule("<",  40, "#f87171")
    %               ])

    properties
        % > MIN minimum value of the range
        Min (1,1) double = 0

        % > MAX maximum value of the range
        Max (1,1) double = 100

        % > SHOWLABEL display formatted value beside the bar
        ShowLabel (1,1) logical = false

        % > LABELFORMAT sprintf-style format (%d, %f, %.Nf, %% for literal %)
        LabelFormat (1,1) string = "%d%%"

        % > VARIANT bar fill color variant
        Variant (1,1) string {mustBeMember(Variant, [ ...
            "primary", "secondary", "success", "warning", "destructive" ...
            ])} = "primary"

        % > COLORRULES conditional bar color rules (first match wins)
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = ProgressBarColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.ProgressBarColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("progressbar", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.Min ~= 0,              cfg.min = this.Min;                     end
            if this.Max ~= 100,             cfg.max = this.Max;                     end
            if this.ShowLabel,              cfg.showLabel = true;                   end
            if this.LabelFormat ~= "%d%%",  cfg.labelFormat = this.LabelFormat;     end
            if this.Variant ~= "primary",   cfg.variant = this.Variant;             end
            if ~isempty(this.ColorRules)
                cfg.colorRules = this.ColorRules.toStruct();
            end
        end
    end

    methods (Access = {?ic.TableBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % Range check (same as NumberColumn)
            data = double(columnData);
            mask = true(numel(data), 1);
            if isfield(filterValue, 'min') && ~isempty(filterValue.min)
                mask = mask & (data >= filterValue.min);
            end
            if isfield(filterValue, 'max') && ~isempty(filterValue.max)
                mask = mask & (data <= filterValue.max);
            end
        end
    end
end
