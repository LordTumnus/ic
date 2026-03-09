classdef TabPanel < ic.core.ComponentContainer
    % > TABPANEL Content container for a tab within ic.TabContainer.
    %
    % Users add children to the panel returned by addTab().

    methods (Access = ?ic.TabContainer)
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
