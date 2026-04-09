classdef DrawerBody < ic.core.ComponentContainer
    % content container for the body area of an #ic.Drawer.
    % Created automatically by the Drawer constructor.

    methods (Access = ?ic.Drawer)
        function this = DrawerBody(props)
            arguments
                props.?ic.drawer.DrawerBody
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end
