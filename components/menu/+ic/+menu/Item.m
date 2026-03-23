classdef Item < ic.menu.Entry
    % clickable leaf action in a context menu.
    % When clicked, the parent component's #ic.mixin.HasContextMenu.ContextMenuAction event fires with the key in its payload.

    properties
        % unique action identifier, returned in the #ic.mixin.HasContextMenu.ContextMenuAction event payload
        Key (1,1) string

        % display text shown in the menu
        Label (1,1) string = ""

        % icon displayed before the label
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % whether the item is grayed out and cannot be clicked
        Disabled (1,1) logical = false

        % display-only keyboard shortcut hint shown on the right side of the item
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
