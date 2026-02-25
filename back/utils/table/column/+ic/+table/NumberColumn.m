classdef NumberColumn < ic.table.Column
    % > NUMBERCOLUMN Numeric column definition.
    %
    %   Displays cell values as formatted numbers with optional prefix/suffix,
    %   thousands separator, and conditional background coloring.
    %
    %   Example:
    %       c = ic.table.NumberColumn("Price", Prefix="$", Decimals=2, ...
    %               ThousandsSeparator=true)
    %       c = ic.table.NumberColumn("Score", Suffix="%", Decimals=1, ...
    %               ColorRules=[
    %                   ic.table.ColorRule(">",  90, "#4ade80")
    %                   ic.table.ColorRule("<",  50, "#f87171")
    %               ])

    properties
        % > DECIMALS number of decimal places (-1 = auto, no rounding)
        Decimals (1,1) double = -1

        % > PREFIX string prepended to the formatted number (e.g. "$")
        Prefix (1,1) string = ""

        % > SUFFIX string appended to the formatted number (e.g. "%")
        Suffix (1,1) string = ""

        % > THOUSANDSSEPARATOR add comma separators for thousands
        ThousandsSeparator (1,1) logical = false

        % > COLORRULES conditional background color rules (first match wins)
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = NumberColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.NumberColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("number", opts);
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

    methods (Access = {?ic.TableBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % Range check: filterValue has optional .min and .max
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
