classdef TextEntry < ic.menu.Entry
    % inline text input in a context menu.
    % Displays a text field next to a label. The entered text is returned as "key:value" in the #ic.mixin.HasContextMenu.ContextMenuAction event payload when the user presses Enter or the input loses focus.

    properties
        % unique action identifier. The #ic.mixin.HasContextMenu.ContextMenuAction payload contains a field with #ic.menu.TextEntry.Key= value
        Key (1,1) string

        % display text shown next to the input
        Label (1,1) string = ""

        % initial text value
        Value (1,1) string = ""

        % ghost text shown when the input is empty
        Placeholder (1,1) string = ""
    end

    methods
        function this = TextEntry(key, opts)
            arguments
                key (1,1) string
                opts.?ic.menu.TextEntry
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
                'type',        'text', ...
                'key',         this.Key, ...
                'label',       this.Label, ...
                'value',       this.Value, ...
                'placeholder', this.Placeholder);
        end
    end
end
