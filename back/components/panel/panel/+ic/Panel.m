classdef Panel < ic.core.ComponentContainer
    % > PANEL Simple container for grouping child components.
    %
    % The Panel provides a minimal container that can hold child components.
    % It serves as a basic building block for organizing UI layouts.
    % Created with display:block, by default fills the width of its container

    methods
        function this = Panel(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(id);
        end
    end
end
