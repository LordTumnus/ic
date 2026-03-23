classdef TextColumn < ic.table.Column
    % text column that displays cell values as plain or rich text.

    properties
        % enable **bold** and _italic_ inline Markdown formatting
        RichText (1,1) logical = false

        % ghost fallback text shown when the cell value is empty
        Placeholder (1,1) string = ""

        % CSS text-transform applied to the displayed text
        Transform (1,1) string {mustBeMember(Transform, ["none","uppercase","lowercase","capitalize"])} = "none"
    end

    methods
        function this = TextColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.TextColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("text", opts);
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

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % case-insensitive substring match
            mask = contains(string(columnData), string(filterValue), ...
                'IgnoreCase', true);
        end
    end
end
