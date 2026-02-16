classdef AvatarColumn < ic.table.Column
    % > AVATARCOLUMN Avatar image column definition.
    %
    %   Displays cell values as circular avatar images with an optional
    %   text label from a companion data field.
    %
    %   Example:
    %       c = ic.table.AvatarColumn("Photo", TextField="Name", Radius=16)

    properties
        % > TEXTFIELD companion data field name for display text next to avatar
        TextField (1,1) string = ""

        % > RADIUS avatar circle radius in pixels
        Radius (1,1) double {mustBePositive} = 14
    end

    methods
        function this = AvatarColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.AvatarColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("avatar", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.TextField ~= "", cfg.textField = this.TextField; end
            if this.Radius ~= 14,   cfg.radius    = this.Radius;    end
        end
    end
end
