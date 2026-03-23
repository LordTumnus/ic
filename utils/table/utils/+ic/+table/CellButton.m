classdef CellButton
    % definition of a single button inside a #ic.table.ButtonColumn cell.
    % When clicked, the button's #ic.table.CellButton.Key is passed to the column's #ic.TableBase.OnCellAction callback via the data.action field.

    properties
        % unique action identifier passed in the #ic.TableBase.OnCellAction callback
        Key (1,1) string

        % button text
        Label (1,1) string = ""

        % icon displayed in the button
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % text displayed on hover
        Tooltip (1,1) string = ""

        % visual style variant
        Variant (1,1) string {mustBeMember(Variant, ...
            ["default", "primary", "destructive"])} = "default"

        % whether the button is disabled
        Disabled (1,1) logical = false
    end

    methods
        function this = CellButton(key, opts)
            % construct a cell button definition.
            % {example}
            %   btns = [
            %       ic.table.CellButton("edit", Label="Edit", Icon="pencil")
            %       ic.table.CellButton("delete", Icon="trash-2", Variant="destructive")
            %   ];
            % {/example}
            arguments
                % unique action key
                key (1,1) string
                opts.?ic.table.CellButton
            end
            this.Key = key;
            opts = rmfield(opts, ...
                intersect(fieldnames(opts), {'Key'}));
            fns = fieldnames(opts);
            for i = 1:numel(fns)
                this.(fns{i}) = opts.(fns{i});
            end
        end

        function s = toStruct(this)
            n = numel(this);
            if n == 0
                s = struct('key',{},'label',{},'icon',{}, ...
                    'tooltip',{},'variant',{},'disabled',{});
                return;
            end
            e = cell(1, n);
            s = struct('key',e,'label',e,'icon',e, ...
                'tooltip',e,'variant',e,'disabled',e);
            for i = 1:n
                s(i).key      = this(i).Key;
                s(i).label    = this(i).Label;
                s(i).icon     = this(i).Icon;
                s(i).tooltip  = this(i).Tooltip;
                s(i).variant  = this(i).Variant;
                s(i).disabled = this(i).Disabled;
            end
        end
    end
end
