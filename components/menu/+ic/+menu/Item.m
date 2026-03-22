classdef Item < ic.menu.Entry
    % > ITEM A clickable leaf action in a context menu.
    %
    %   Example:
    %       ic.menu.Item("copy", Label="Copy Name", Icon="clipboard")
    %       ic.menu.Item("delete", Label="Delete", Icon="trash-2", Shortcut="Del")

    properties
        % > KEY unique action identifier (returned in event payload)
        Key (1,1) string

        % > LABEL display text
        Label (1,1) string = ""

        % > ICON icon source (Lucide name, file path, or URL)
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % > DISABLED whether the item is grayed out
        Disabled (1,1) logical = false

        % > SHORTCUT display-only keyboard shortcut hint
        Shortcut (1,1) string = ""
    end

    methods
        function this = Item(key, opts)
            arguments
                key (1,1) string
                opts.?ic.menu.Item
            end
            this.Key = key;
            opts = rmfield(opts, ...
                intersect(fieldnames(opts), {'Key'}));
            if ~isempty(fieldnames(opts))
                set(this, opts);
            end
        end

        function s = toStruct(this)
            s = struct( ...
                'type',     'item', ...
                'key',      this.Key, ...
                'label',    this.Label, ...
                'icon',     this.Icon, ...
                'disabled', this.Disabled, ...
                'shortcut', this.Shortcut);
        end
    end
end
