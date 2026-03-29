classdef ImageColumn < ic.table.Column
    % image column that displays cell values as thumbnails with a hover preview popup.
    % Cell data must be an #ic.Asset (file or URL) per row.

    properties
        % width of the hover preview popup, in pixels
        PopupWidth (1,1) double {mustBePositive} = 200

        % height of the hover preview popup, in pixels
        PopupHeight (1,1) double {mustBePositive} = 150

        % CSS [object-fit](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/object-fit#browser_compatibility) for the preview image
        ObjectFit (1,1) string {mustBeMember(ObjectFit, [ ...
            "contain", "cover", "fill", "none", "scale-down" ...
            ])} = "contain"
    end

    methods
        function this = ImageColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.ImageColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("image", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.PopupWidth ~= 200,       cfg.popupWidth = this.PopupWidth;   end
            if this.PopupHeight ~= 150,       cfg.popupHeight = this.PopupHeight; end
            if this.ObjectFit ~= "contain",   cfg.objectFit = this.ObjectFit;     end
        end
    end
end
