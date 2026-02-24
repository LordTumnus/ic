classdef DateColumn < ic.table.Column
    % > DATECOLUMN Date/datetime column with format presets.
    %
    %   Displays date values formatted using named presets. Sorting is
    %   chronological. Filter uses a date-range picker.
    %
    %   MATLAB datetime arrays serialize to ISO 8601 via jsonencode,
    %   which the frontend parses natively.
    %
    %   Example:
    %       c = ic.table.DateColumn("BirthDate", ...
    %           Format="short", Sortable=true, Filterable=true)

    properties
        % > FORMAT display format preset
        Format (1,1) string {mustBeMember(Format, [ ...
            "short", "long", "numeric", "iso", "datetime", "time" ...
            ])} = "short"

        % > COLORRULES conditional background color rules (first match wins)
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = DateColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.DateColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("date", opts);
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
end
