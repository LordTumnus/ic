classdef TabPanel < ic.core.ComponentContainer
    % content container for a tab within an #ic.TabContainer or #ic.TileLayout.
    % Add child components to the panel returned by #ic.TabContainer.addTab or #ic.TileLayout.addTab.

    methods (Access = {?ic.TabContainer, ?ic.TileLayout})
        function this = TabPanel(props)
            arguments
                props.?ic.tab.TabPanel
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = "default";
        end
    end
end
