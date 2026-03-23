classdef Panel < ic.core.ComponentContainer
    % content container for an #ic.Popover.
    % Add child components here via #ic.core.ComponentContainer.addChild. Created automatically by the Popover constructor.

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
