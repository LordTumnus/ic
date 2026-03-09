classdef Tab < ic.core.Component
    % > TAB Header configuration for a tab within ic.TabContainer.
    %
    % Tab is a plain component (not a container). It holds the reactive
    % properties for its tab header (label, icon, closable, disabled) and
    % a reference to its paired TabPanel set by TabContainer.addTab().

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed in the tab header
        Label (1,1) string = ""

        % > CLOSABLE whether the tab shows a close button
        Closable (1,1) logical = false

        % > DISABLED whether the tab is disabled (cannot be selected)
        Disabled (1,1) logical = false

        % > ICON icon displayed before the label (Lucide name, .svg file, or URL)
        Icon ic.asset.Asset = ic.asset.Asset.empty
    end

    properties (SetAccess = ?ic.TabContainer)
        % > PANEL reference to the paired TabPanel (set by addTab)
        Panel
    end

    methods (Access = ?ic.TabContainer)
        function this = Tab(props)
            arguments
                props.?ic.tab.Tab
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end
