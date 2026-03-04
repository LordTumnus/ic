classdef Panel < ic.core.ComponentContainer
    % > PANEL Content container for ic.Popover.

    methods (Access = ?ic.Popover)
        function this = Panel(props)
            arguments
                props.?ic.popover.Panel
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = "default";
        end
    end
end
