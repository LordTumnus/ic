classdef DrawerHeader < ic.core.ComponentContainer
    % content container for the header area of an #ic.Drawer.
    % Created automatically by the Drawer constructor.

    methods (Access = ?ic.Drawer)
        function this = DrawerHeader(props)
            arguments
                props.?ic.drawer.DrawerHeader
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end
