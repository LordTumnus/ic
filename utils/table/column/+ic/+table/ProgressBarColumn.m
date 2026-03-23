classdef ProgressBarColumn < ic.table.Column
    % inline progress bar column for numeric values within a range.

    properties
        % minimum value of the range (maps to 0% fill)
        Min (1,1) double = 0

        % maximum value of the range (maps to 100% fill)
        Max (1,1) double = 100

        % whether to display the formatted value next to the bar
        ShowLabel (1,1) logical = false

        % sprintf-style format for the label (supports %d, %f, %.Nf, %% for literal %)
        LabelFormat (1,1) string = "%d%%"

        % bar fill color variant
        Variant (1,1) string {mustBeMember(Variant, [ ...
            "primary", "secondary", "success", "warning", "destructive" ...
            ])} = "primary"

        % conditional bar color rules evaluated against the cell value. First matching rule wins
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

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % range check (same as NumberColumn)
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
