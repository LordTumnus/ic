classdef ColorColumn < ic.table.Column
    % > COLORCOLUMN Color swatch column with inline picker editing.
    %
    %   Displays cell values as colored swatches. Double-click opens a
    %   color-picker popup with saturation/value pad, hue slider, and
    %   optional alpha slider.
    %
    %   Example:
    %       c = ic.table.ColorColumn("Color", ...
    %           Format="hex", ShowAlpha=false, Editable=true)
    %       c = ic.table.ColorColumn("BgColor", ...
    %           Format="rgb", ShowAlpha=true, ...
    %           Presets=["#ef4444","#f59e0b","#22c55e","#3b82f6"])

    properties
        % > FORMAT output color string format ("hex", "rgb", or "hsl")
        Format (1,1) string {mustBeMember(Format, ...
            ["hex", "rgb", "hsl"])} = "hex"

        % > SHOWALPHA whether to show the alpha slider in the editor
        ShowAlpha (1,1) logical = false

        % > PRESETS optional preset color swatches shown below the picker
        Presets (1,:) string = string.empty
    end

    methods
        function this = ColorColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.ColorColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("color", opts);
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
