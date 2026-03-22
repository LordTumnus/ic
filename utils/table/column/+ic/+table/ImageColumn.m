classdef ImageColumn < ic.table.Column
    % > IMAGECOLUMN Image column definition.
    %
    %   Displays cell values (ic.Asset images) as a small thumbnail
    %   indicator in the row. Hovering reveals a larger preview popup.
    %
    %   Cell data must be an ic.Asset (file or URL) per row.
    %   Use a cell column in the MATLAB table to store variable-type values,
    %   or an ic.Asset array column.
    %
    %   Example:
    %       c = ic.table.ImageColumn("photo", ...
    %               Header="Photo", Width=60, ...
    %               PopupWidth=240, PopupHeight=180)

    properties
        % > POPUPWIDTH width of the hover preview popup in px
        PopupWidth (1,1) double {mustBePositive} = 200

        % > POPUPHEIGHT height of the hover preview popup in px
        PopupHeight (1,1) double {mustBePositive} = 150

        % > OBJECTFIT CSS object-fit for the preview image
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
