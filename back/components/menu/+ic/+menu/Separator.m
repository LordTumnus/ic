classdef Separator < ic.menu.Entry
    % > SEPARATOR A visual divider line in a context menu.
    %
    %   Example:
    %       menu = [ic.menu.Item("a"), ic.menu.Separator(), ic.menu.Item("b")];

    methods
        function this = Separator()
        end

        function s = toStruct(this) %#ok<MANU>
            s = struct('type', 'separator');
        end
    end
end
