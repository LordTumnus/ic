classdef TextEntry < ic.menu.Entry
    % > TEXTENTRY An inline text input in a context menu.
    %
    %   The entered text is returned as "key:value" in the action payload
    %   when the user presses Enter or the input loses focus.
    %
    %   Example:
    %       ic.menu.TextEntry("name", Label="Name", Placeholder="Enter name...")

    properties
        % > KEY unique action identifier (returned as "key:value")
        Key (1,1) string

        % > LABEL display text next to the input
        Label (1,1) string = ""

        % > VALUE initial text value
        Value (1,1) string = ""

        % > PLACEHOLDER hint text shown when input is empty
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
