classdef EnumColumn < ic.table.Column
    % > ENUMCOLUMN Categorical column with fixed values, per-value coloring,
    %   and ordinal sorting.
    %
    %   Displays cell values as colored tag pills. Sorting uses the Items
    %   array order (first = lowest). Filtering shows a checkbox dropdown.
    %
    %   Example:
    %       c = ic.table.EnumColumn("Status", ...
    %           Items=["Active","Inactive","Pending","Archived"], ...
    %           Colors=["#4ade80","#f87171","#facc15","#94a3b8"])

    properties
        % > ITEMS ordered set of allowed values (also defines sort priority)
        Items (1,:) string = string.empty

        % > COLORS hex color per item (parallel to Items). "" = no color.
        Colors (1,:) string = string.empty
    end

    methods
        function this = EnumColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.EnumColumn
            end
            this@ic.table.Column(field);
            this.initFromOpts("enum", opts);
        end

        function set.Colors(this, val)
            if ~isempty(val) && ~isempty(this.Items) && numel(val) ~= numel(this.Items) %#ok<MCSUP>
                error('ic:table:EnumColumn:colorsMismatch', ...
                    'Colors must be empty or same length as Items (%d).', numel(this.Items)); %#ok<MCSUP>
            end
            this.Colors = val;
        end
    end

    methods (Access = protected)
        function cfg = buildConfig(this)
            cfg = struct();
            if ~isempty(this.Items)
                cfg.items = this.Items;
                if ~isempty(this.Colors)
                    cfg.colors = this.Colors;
                end
            end
        end
    end

    methods (Access = {?ic.TableBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % Membership check: filterValue is a string/cell array of selected items
            selected = string(filterValue);
            if isempty(selected)
                mask = true(numel(columnData), 1);
            else
                mask = ismember(string(columnData), selected);
            end
        end

        function keys = sortKey(this, columnData)
            % Sort by ordinal position in Items (first = lowest)
            items = this.Items;
            if isempty(items)
                keys = string(columnData);
                return;
            end
            [~, keys] = ismember(string(columnData), items);
            % Unmapped values (0 from ismember) sort to end
            keys(keys == 0) = numel(items) + 1;
        end
    end
end
