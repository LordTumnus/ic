classdef Panel < ic.core.ComponentContainer
    % simple container for grouping child components.

    methods
        function this = Panel(props)
            arguments
                props.?ic.Panel
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end
