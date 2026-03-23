classdef ColorColumn < ic.table.Column
    % color swatch column with inline color-picker editing.
    % Displays cell values as colored swatches. When Editable, double-clicking opens a color picker popup.

    properties
        % output color string format
        Format (1,1) string {mustBeMember(Format, ...
            ["hex", "rgb", "hsl"])} = "hex"

        % whether to show the alpha slider in the inline editor
        ShowAlpha (1,1) logical = false

        % optional preset color swatches shown below the picker
        Presets (1,:) string = string.empty
    end

    methods
        function this = ColorColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.ColorColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("color", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.Format ~= "hex"
                cfg.format = this.Format;
            end
            if this.ShowAlpha
                cfg.showAlpha = true;
            end
            if ~isempty(this.Presets)
                cfg.presets = this.Presets;
            end
        end
    end
end
