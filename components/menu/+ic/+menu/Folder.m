classdef Folder < ic.menu.Entry
    % submenu container in a context menu.
    % Displays a label that expands into a nested list of child entries on hover.

    properties
        % display text for the submenu trigger
        Label (1,1) string = ""

        % icon displayed before the label
        Icon ic.Asset = ic.Asset.empty

        % nested menu entries displayed when the folder is expanded
        Children ic.menu.Entry = ic.menu.Entry.empty

        % whether the folder is grayed out and cannot be expanded
        Disabled (1,1) logical = false
    end

    methods
        function this = Folder(opts)
            arguments
                opts.?ic.menu.Folder
            end
            if ~isempty(fieldnames(opts))
                set(this, opts);
            end
        end

        function s = toStruct(this)
            % recursively serialize children
            if isempty(this.Children)
                ch = [];
            else
                c = cell(1, numel(this.Children));
                for i = 1:numel(this.Children)
                    c{i} = this.Children(i).toStruct();
                end
                ch = c;
            end
            s = struct( ...
                'type',     'folder', ...
                'label',    this.Label, ...
                'icon',     this.Icon, ...
                'disabled', this.Disabled, ...
                'children', {ch});
        end
    end
end
