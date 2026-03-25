classdef Tab < ic.core.Component
    % header configuration for a tab within an #ic.TabContainer or #ic.TileLayout.
    % Tab is not a container, it simply holds the reactive properties for its tab header (label, icon, closable, disabled) and a reference to its paired #ic.tab.TabPanel. Create tabs via #ic.TabContainer.addTab or #ic.TileLayout.addTab, not directly.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % text displayed in the tab header
        Label (1,1) string = ""

        % whether the tab shows a close button
        Closable (1,1) logical = false

        % whether the tab is disabled and cannot be selected
        Disabled (1,1) logical = false

        % icon displayed before the label
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % whether the tab label can be renamed by double-clicking on it
        Editable (1,1) logical = false
    end

    properties (SetAccess = {?ic.TabContainer, ?ic.TileLayout})
        % reference to the paired #ic.tab.TabPanel
        Panel
    end

    methods (Access = {?ic.TabContainer, ?ic.TileLayout})
        function this = Tab(props)
            arguments
                props.?ic.tab.Tab
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end
