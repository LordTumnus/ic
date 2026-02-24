classdef CellButton < matlab.mixin.SetGetExactNames
    % > CELLBUTTON Definition of a single button inside a ButtonColumn cell.
    %
    %   Value class defining a button's appearance and identity.
    %   Used in arrays to populate ButtonColumn.Buttons.
    %
    %   Example:
    %       btns = [
    %           ic.table.CellButton("edit",   Label="Edit",   Icon="pencil")
    %           ic.table.CellButton("delete", Icon="trash-2", Variant="destructive")
    %       ];

    properties
        % > KEY unique action identifier (returned in OnCellAction payload)
        Key (1,1) string

        % > LABEL button text (empty = icon-only)
        Label (1,1) string = ""

        % > ICON icon source (Lucide name, file path, or URL)
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % > TOOLTIP hover tooltip text
        Tooltip (1,1) string = ""

        % > VARIANT visual style
        Variant (1,1) string {mustBeMember(Variant, ...
            ["default", "primary", "destructive"])} = "default"

        % > DISABLED whether the button is disabled
        Disabled (1,1) logical = false
    end

    methods
        function this = CellButton(key, opts)
            arguments
                key (1,1) string
                opts.?ic.table.CellButton
            end
            this.Key = key;
            opts = rmfield(opts, ...
                intersect(fieldnames(opts), {'Key'}));
            if ~isempty(fieldnames(opts))
                set(this, opts);
            end
        end

        function s = toStruct(this)
            % > TOSTRUCT Convert array to struct array for JSON.
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
