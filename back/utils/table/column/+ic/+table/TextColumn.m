classdef TextColumn < ic.table.Column
    % > TEXTCOLUMN Plain text column definition.
    %
    %   Displays cell values as text with optional formatting.
    %
    %   Example:
    %       c = ic.table.TextColumn("Name", Sortable=true, Width=200)
    %       c = ic.table.TextColumn("Notes", RichText=true, Placeholder="—")
    %       c = ic.table.TextColumn("Code", Transform="uppercase")

    properties
        % > RICHTEXT enable **bold** and *italic* inline formatting
        RichText (1,1) logical = false

        % > PLACEHOLDER muted fallback text when cell value is empty
        Placeholder (1,1) string = ""

        % > TRANSFORM CSS text-transform: "none"|"uppercase"|"lowercase"|"capitalize"
        Transform (1,1) string {mustBeMember(Transform, ["none","uppercase","lowercase","capitalize"])} = "none"
    end

    methods
        function this = TextColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.TextColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("text", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.RichText
                cfg.richText = true;
            end
            if this.Placeholder ~= ""
                cfg.placeholder = this.Placeholder;
            end
            if this.Transform ~= "none"
                cfg.transform = this.Transform;
            end
        end
    end
end
