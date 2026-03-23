classdef NumberColumn < ic.table.Column
    % numeric column with formatting, prefix/suffix, and conditional coloring.

    properties
        % number of decimal places to display (-1 = auto, no rounding)
        Decimals (1,1) double = -1

        % string prepended to the formatted number
        Prefix (1,1) string = ""

        % string appended to the formatted number
        Suffix (1,1) string = ""

        % whether to add comma separators for thousands
        ThousandsSeparator (1,1) logical = false

        % conditional background color rules evaluated against the cell value
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = NumberColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.NumberColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("number", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            cfg.decimals           = this.Decimals;
            cfg.prefix             = this.Prefix;
            cfg.suffix             = this.Suffix;
            cfg.thousandsSeparator  = this.ThousandsSeparator;
            if ~isempty(this.ColorRules)
                cfg.colorRules = this.ColorRules.toStruct();
            end
        end
    end

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % range check: filterValue has optional .min and .max
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
