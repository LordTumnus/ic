classdef TabContainer < ic.core.ComponentContainer
    % tabbed container with closable, renamable, and reorderable tabs.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % how tabs behave when they overflow the tab bar. When "scroll", tab headers remain in a single line and can be scrolled; when "wrap", the tab header bar is wrapped to multiple lines; "menu" makes overflowed tabs are collapsed into a dropdown menu.
        TabOverflow (1,1) string {mustBeMember(TabOverflow, ...
            ["scroll", "wrap", "menu"])} = "scroll"

        % whether all tab interactions are disabled
        Disabled (1,1) logical = false

        % whether tabs can be reordered via drag-and-drop
        DragEnabled (1,1) logical = true

        % dimension of the tab headers relative to the component font size
        Size (1,1) string {mustBeMember(Size, ...
            ["sm", "md", "lg"])} = "md"
    end

    properties (SetObservable, AbortSet, SetAccess = {?ic.TabContainer, ?ic.mixin.Reactive}, Description = "Reactive")
        % target string of the currently selected tab (e.g. "tab-0"). Set by the framework when the user clicks a tab
        SelectedTab (1,1) string = ""
    end

    properties (Dependent, SetAccess = private)
        % array of #ic.tab.Tab children (read-only)
        Tabs

        % array of #ic.tab.TabPanel children (read-only)
        Panels

        % the currently selected Tab handle, or empty if none. Use #ic.TabContainer.selectTab() to programmatically select a tab.
        Selected
    end

    properties (Access = private)
        % monotonic counter
        NextTabIndex (1,1) double = 0

        % guard flag: prevents handleTabDestroyed from duplicating
        % cleanup that removeTab already handles.
        IsRemovingTab (1,1) logical = false
    end

    events (Description = "Reactive")
        % fires when the selected tab changes
        % {payload}
        % value | char: target string of the newly selected tab (e.g. 'tab-0')
        % {/payload}
        ValueChanged

        % fires when a tab's close button is clicked. The tab is automatically deleted after this event
        % {payload}
        % value | char: target string of the closed tab
        % {/payload}
        TabClosed

        % fires when tabs are reordered via drag-and-drop
        % {payload}
        % value | cell array: ordered list of tab target strings after reordering
        % {/payload}
        TabReordered

        % fires when a tab label is edited via double-click
        % {payload}
        % value | struct: struct with fields 'target' (char) and 'label' (char)
        % {/payload}
        TabRenamed
    end

    methods
        function this = TabContainer(props)
            arguments
                props.?ic.TabContainer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);

            % auto-delete tabs when closed from the UI
            addlistener(this, 'TabClosed', ...
                @(~, e) this.removeTab(e.Data.value));
        end

        function tabs = get.Tabs(this)
            if isempty(this.Children)
                tabs = ic.tab.Tab.empty();
            else
                mask = arrayfun(@(c) isa(c, 'ic.tab.Tab'), this.Children);
                tabs = this.Children(mask);
            end
        end

        function panels = get.Panels(this)
            if isempty(this.Children)
                panels = ic.tab.TabPanel.empty();
            else
                mask = arrayfun(@(c) isa(c, 'ic.tab.TabPanel'), this.Children);
                panels = this.Children(mask);
            end
        end

        function tab = get.Selected(this)
            % returns the currently selected Tab, or empty
            tabs = this.Tabs;
            if isempty(tabs) || this.SelectedTab == ""
                tab = ic.tab.Tab.empty();
                return;
            end
            mask = arrayfun(@(t) t.Target == this.SelectedTab, tabs);
            idx = find(mask, 1);
            if isempty(idx)
                tab = ic.tab.Tab.empty();
            else
                tab = tabs(idx);
            end
        end

        function [panel, tab] = addTab(this, name, props)
            % add a new tab to the container.
            % {returns} the #ic.tab.TabPanel (content area) and #ic.tab.Tab (header) {/returns}
            % {example}
            %   tc = ic.TabContainer();
            %   [panel, tab] = tc.addTab("Home", Icon="home", Closable=true);
            %   panel.addChild(ic.Button(Label="Click me"));
            % {/example}
            arguments
                this
                % label for the new tab
                name (1,1) string = ""
                % whether the tab can be closed by the user
                props.Closable (1,1) logical = false
                % whether the tab is disabled
                props.Disabled (1,1) logical = false
                % optional icon for the tab header
                props.Icon ic.asset.Asset = ic.asset.Asset.empty
            end

            idx = this.NextTabIndex;
            this.NextTabIndex = idx + 1;

            tabTarget = sprintf("tab-%d", idx);
            panelTarget = sprintf("panel-%d", idx);

            % build Tab
            tabProps = struct();
            tabProps.ID = this.ID + "-tab-" + idx;
            tabProps.Label = name;
            if isfield(props, 'Closable')
                 tabProps.Closable = props.Closable;
            end
            if isfield(props, 'Disabled')
                tabProps.Disabled = props.Disabled;
            end
            if isfield(props, 'Icon')
                 tabProps.Icon = props.Icon;
            end

            args = namedargs2cell(tabProps);
            tab = ic.tab.Tab(args{:});

            % build TabPanel
            panel = ic.tab.TabPanel(ID = this.ID + "-panel-" + idx);

            % link Tab to Panel
            tab.Panel = panel;

            % register targets before adding children
            this.Targets = [this.Targets, tabTarget, panelTarget];
            this.addChild(tab, tabTarget);
            this.addChild(panel, panelTarget);

            % listen for direct delete(tab) and clean up selection/targets
            addlistener(tab, 'ObjectBeingDestroyed', ...
                @(src, ~) this.handleTabDestroyed(src));

            % auto-select first tab
            if this.SelectedTab == ""
                this.SelectedTab = tabTarget;
            end
        end

        function removeTab(this, tabOrTarget)
            % remove and delete a tab from the container.
            % Accepts a #ic.tab.Tab handle or a target string
            % {example}
            %   tc.removeTab(tab);
            %   tc.removeTab("tab-2");
            % {/example}
            arguments
                this
                % handle of the tab to remove, or target string
                tabOrTarget
            end

            if isstring(tabOrTarget) || ischar(tabOrTarget)
                target = string(tabOrTarget);
                tab = this.findTabByTarget(target);
            else
                tab = tabOrTarget;
                target = tab.Target;
            end

            panel = tab.Panel;
            panelTarget = panel.Target;
            wasSelected = (this.SelectedTab == target);

            % find adjacent tab for re-selection
            tabs = this.Tabs;
            tabTargets = arrayfun(@(t) t.Target, tabs);
            pos = find(tabTargets == target, 1);

            % guard and delete
            this.IsRemovingTab = true;
            delete(tab);
            if isvalid(panel), delete(panel); end
            this.IsRemovingTab = false;

            % remove both targets
            this.Targets(this.Targets == target | ...
                         this.Targets == panelTarget) = [];

            % adjust selection: prefer previous tab, fall back to first
            if wasSelected
                remainingTabs = this.Tabs;
                n = numel(remainingTabs);
                if n > 0
                    newPos = max(pos - 1, 1);
                    this.SelectedTab = remainingTabs(newPos).Target;
                else
                    this.SelectedTab = "";
                end
            end
        end

        function selectTab(this, tab)
            % programmatically select a tab
            % {example}
            %   tc.selectTab(t2);
            % {/example}
            arguments
                this
                % handle of the tab to select
                tab (1,1) ic.tab.Tab
            end
            this.SelectedTab = tab.Target;
        end
    end

    methods (Hidden)
        function validateChild(this, child, target)
            assert(isa(child, "ic.tab.Tab") || isa(child, "ic.tab.TabPanel"), ...
                "ic:TabContainer:InvalidChild", ...
                "TabContainer only accepts Tab and TabPanel children. " + ...
                "Use tc.addTab() to create tabs.");

            validateChild@ic.core.ComponentContainer(this, child, target);
        end
    end

    methods (Access = private)
        function handleTabDestroyed(this, tab)
            if ~isvalid(this), return; end
            if this.IsRemovingTab, return; end

            target = tab.Target;
            panel = tab.Panel;
            wasSelected = (this.SelectedTab == target);

            % find position before removing (for previous-tab selection)
            tabTargets = this.Targets(startsWith(this.Targets, "tab-"));
            pos = find(tabTargets == target, 1);

            % remove panel
            if ~isempty(panel) && isvalid(panel)
                panelTarget = panel.Target;
                delete(panel);
                this.Targets(this.Targets == panelTarget) = [];
            end

            % remove tab target
            this.Targets(this.Targets == target) = [];

            % adjust selection: prefer previous tab
            if wasSelected
                remainingTabs = this.Tabs;
                n = numel(remainingTabs);
                if n > 0
                    newPos = max(pos - 1, 1);
                    this.SelectedTab = remainingTabs(newPos).Target;
                else
                    this.SelectedTab = "";
                end
            end
        end

        function tab = findTabByTarget(this, target)
            tabs = this.Tabs;
            mask = arrayfun(@(t) t.Target == target, tabs);
            idx = find(mask, 1);
            assert(~isempty(idx), "ic:TabContainer:TabNotFound", ...
                "No tab with target '%s'", target);
            tab = tabs(idx);
        end
    end
end
