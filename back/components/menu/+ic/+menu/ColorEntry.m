classdef ColorEntry < ic.menu.Entry
    % > COLORENTRY An inline color picker in a context menu.
    %
    %   The picked color is returned as "key:#hex" in the action payload.
    %
    %   Example:
    %       ic.menu.ColorEntry("bg", Label="Background", Value="#3b82f6")

    properties
        % > KEY unique action identifier (returned as "key:#hex")
        Key (1,1) string

        % > LABEL display text next to the swatch
        Label (1,1) string = ""

        % > VALUE initial hex color string
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
