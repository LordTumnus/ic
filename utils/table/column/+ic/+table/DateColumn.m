classdef DateColumn < ic.table.Column
    % date/datetime column with format presets and chronological sorting.

    properties
        % display format preset
        Format (1,1) string {mustBeMember(Format, [ ...
            "short", "long", "numeric", "iso", "datetime", "time" ...
            ])} = "short"

        % conditional background color rules evaluated against the date value
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = DateColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.DateColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("date", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.Format ~= "short"
                cfg.format = this.Format;
            end
            if ~isempty(this.ColorRules)
                cfg.colorRules = this.ColorRules.toStruct();
            end
        end
    end

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % date range check: filterValue has optional .min and .max (ISO strings)
            mask = true(numel(columnData), 1);
            if isfield(filterValue, 'min') && ~isempty(filterValue.min)
                minDate = datetime(string(filterValue.min), ...
                    'InputFormat', 'yyyy-MM-dd');
                if ~isempty(columnData.TimeZone)
                    minDate.TimeZone = columnData.TimeZone;
                end
                mask = mask & (columnData >= minDate);
            end
            if isfield(filterValue, 'max') && ~isempty(filterValue.max)
                maxDate = datetime(string(filterValue.max), ...
                    'InputFormat', 'yyyy-MM-dd');
                if ~isempty(columnData.TimeZone)
                    maxDate.TimeZone = columnData.TimeZone;
                end
                % end of day inclusive
                maxDate = maxDate + days(1) - milliseconds(1);
                mask = mask & (columnData <= maxDate);
            end
        end

        function val = coerceEditValue(~, rawValue, colData)
            if ischar(rawValue), rawValue = string(rawValue); end
            val = datetime(rawValue, ...
                'InputFormat', "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", ...
                'TimeZone', 'UTC');
            if isempty(colData.TimeZone)
                val.TimeZone = '';
            else
                val.TimeZone = colData.TimeZone;
            end
        end
    end
end
