classdef Folder < ic.menu.Entry
    % > FOLDER A submenu container in a context menu.
    %
    %   Example:
    %       ic.menu.Folder(Label="Export", Icon="download", Children=[
    %           ic.menu.Item("csv",  Label="As CSV",  Icon="file-text")
    %           ic.menu.Item("pdf",  Label="As PDF",  Icon="file")
    %           ic.menu.Item("xlsx", Label="As Excel", Icon="table")
    %       ])

    properties
        % > LABEL display text for the submenu trigger
        Label (1,1) string = ""

        % > ICON icon source (Lucide name, file path, or URL)
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % > CHILDREN nested menu entries
        Children ic.menu.Entry = ic.menu.Entry.empty

        % > DISABLED whether the folder is grayed out
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
            % Recursively serialize children
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
