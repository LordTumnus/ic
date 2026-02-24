classdef RatingColumn < ic.table.Column
    % > RATINGCOLUMN Star-rating column for bounded numeric values.
    %
    %   Renders values as filled/half-filled/empty stars. Sorting is
    %   numeric. Filter uses a clickable star selector for minimum rating.
    %
    %   Example:
    %       c = ic.table.RatingColumn("Rating", ...
    %           MaxStars=5, AllowHalf=true, Color="#f59e0b")

    properties
        % > MAXSTARS maximum number of stars (default 5)
        MaxStars (1,1) double {mustBePositive, mustBeInteger} = 5

        % > ALLOWHALF display half-star increments (default true)
        AllowHalf (1,1) logical = true

        % > COLOR hex color for filled stars (default amber)
        Color (1,1) string = "#f59e0b"

        % > COLORRULES conditional background color rules (first match wins)
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = RatingColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.RatingColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("rating", opts);
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if this.MaxStars ~= 5
                cfg.maxStars = this.MaxStars;
            end
            if ~this.AllowHalf
                cfg.allowHalf = false;
            end
            if this.Color ~= "#f59e0b"
                cfg.color = this.Color;
            end
            if ~isempty(this.ColorRules)
                cfg.colorRules = this.ColorRules.toStruct();
            end
        end
    end
end
