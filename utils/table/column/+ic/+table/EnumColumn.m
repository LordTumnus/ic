classdef EnumColumn < ic.table.Column
    % categorical column with a fixed set of values displayed as colored tag pills.

    properties
        % ordered set of allowed values. Item order defines sorting priority
        Items (1,:) string = string.empty

        % hex color per item, parallel to Items. An empty value or missing color means "default text color
        Colors (1,:) string = string.empty
    end

    methods
        function this = EnumColumn(field, opts)
            arguments
                field (1,1) string
                opts.?ic.table.EnumColumn
            end
            this@ic.table.Column(field);
            this = this.initFromOpts("enum", opts);
        end

        function this = set.Colors(this, val)
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

    methods (Access = {?ic.TableBase, ?ic.TreeBase, ?ic.table.Column})
        function mask = filterColumn(~, columnData, filterValue)
            % membership check: filterValue is a string/cell array of selected items
            selected = string(filterValue);
            if isempty(selected)
                mask = true(numel(columnData), 1);
            else
                mask = ismember(string(columnData), selected);
            end
        end

        function keys = sortKey(this, columnData)
            % sort by ordinal position in Items (first = lowest)
            items = this.Items;
            if isempty(items)
                keys = string(columnData);
                return;
            end
            [~, keys] = ismember(string(columnData), items);
            % unmapped values (0 from ismember) sort to end
            keys(keys == 0) = numel(items) + 1;
        end
    end
end
