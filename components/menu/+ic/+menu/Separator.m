classdef Separator < ic.menu.Entry
    % visual divider line in a context menu.

    methods
        function this = Separator()
        end

        function s = toStruct(this) %#ok<MANU>
            s = struct('type', 'separator');
        end
    end
end
