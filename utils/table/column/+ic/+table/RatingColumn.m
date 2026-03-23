classdef RatingColumn < ic.table.Column
    % star-rating column for bounded numeric values.

    properties
        % maximum number of stars
        MaxStars (1,1) double {mustBePositive, mustBeInteger} = 5

        % whether to display half-star increments
        AllowHalf (1,1) logical = true

        % hex color for filled stars
        Color (1,1) string = "#f59e0b"

        % conditional background color rules evaluated against the numeric rating
        ColorRules ic.table.ColorRule = ic.table.ColorRule.empty
    end

    methods
        function this = RatingColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.RatingColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("rating", opts);
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

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % range check (same as NumberColumn)
            data = double(columnData);
            mask = true(numel(data), 1);
            if isfield(filterValue, 'min') && ~isempty(filterValue.min)
                mask = mask & (data >= filterValue.min);
            end
            if isfield(filterValue, 'max') && ~isempty(filterValue.max)
                mask = mask & (data <= filterValue.max);
            end
        end
    end
end
