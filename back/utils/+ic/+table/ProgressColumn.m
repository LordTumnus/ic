classdef ProgressColumn < ic.table.Column
    % > PROGRESSCOLUMN Progress bar column definition.
    %
    %   Displays cell values (0–1) as horizontal progress bars.
    %
    %   Example:
    %       c = ic.table.ProgressColumn("Completion", Variant="success")
    %       c = ic.table.ProgressColumn("BMI", Header="BMI Range", Variant="warning")

    properties
        % > VARIANT color variant for the progress bar fill
        Variant (1,1) string {mustBeMember(Variant, [ ...
            "primary","secondary","success","warning","destructive" ...
            ])} = "primary"
    end

    methods
        function this = ProgressColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.ProgressColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("progress", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.Variant ~= "primary", cfg.variant = this.Variant; end
        end
    end
end
