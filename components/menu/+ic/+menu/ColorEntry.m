classdef ColorEntry < ic.menu.Entry
    % inline color picker in a context menu.
    % Displays a color swatch next to a label. The picked color is returned as "key: #hex" in the ContextMenuAction event payload.

    properties
        % unique action identifier. The #ic.mixin.hasContextMenu.ContextMenuAction payload contains an entry with #ic.menu.ColorEntry.Key=value
        Key (1,1) string

        % display text shown next to the color swatch
        Label (1,1) string = ""

        % color value as a hex string
        Value (1,1) string = "#000000"
    end

    methods
        function this = ColorEntry(key, opts)
            arguments
                key (1,1) string
                opts.?ic.menu.ColorEntry
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
                'type',  'color', ...
                'key',   this.Key, ...
                'label', this.Label, ...
                'value', this.Value);
        end
    end
end
