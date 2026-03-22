classdef TabContainer < ic.core.ComponentContainer
    % > TABCONTAINER Tabbed container with closable tabs.
    %
    % Both Tab and TabPanel are direct children. Targets use a monotonic
    % counter ("tab-0", "panel-0", "tab-3", "panel-3") so indices are
    % stable across deletes — no renumbering.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > TABOVERFLOW how tabs overflow: 'scroll', 'wrap', or 'menu'
        TabOverflow (1,1) string {mustBeMember(TabOverflow, ...
            ["scroll", "wrap", "menu"])} = "scroll"

        % > DISABLED disable all tab interactions when true
        Disabled (1,1) logical = false

        % > DRAGENABLED enable drag-and-drop tab reordering
        DragEnabled (1,1) logical = true

        % > SIZE tab header size: 'sm', 'md', or 'lg'
        Size (1,1) string {mustBeMember(Size, ...
            ["sm", "md", "lg"])} = "md"
    end

    properties (SetObservable, AbortSet, SetAccess = {?ic.TabContainer, ?ic.mixin.Reactive}, Description = "Reactive")
        % > SELECTEDTAB target string of the selected tab ("tab-0", etc.)
        SelectedTab (1,1) string = ""
    end

    properties (Dependent, SetAccess = private)
        % > TABS array of Tab children (read-only)
        Tabs

        % > PANELS array of TabPanel children (read-only)
        Panels

        % > SELECTED the currently selected Tab handle, or empty
        Selected
    end

    properties (Access = private)
        % Monotonic counter — never decremented, ensures unique targets
        NextTabIndex (1,1) double = 0

        % Guard flag: prevents handleTabDestroyed from duplicating
        % cleanup that removeTab already handles.
        IsRemovingTab (1,1) logical = false
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the selected tab changes
        ValueChanged

        % > TABCLOSED fires when a tab's close button is clicked
        TabClosed

        % > TABREORDERED fires when tabs are reordered via drag-and-drop
        TabReordered

        % > TABRENAMED fires when a tab label is edited via double-click
        TabRenamed
    end

    methods
        function this = TabContainer(props)
            % > TABCONTAINER Create a tabbed container.
            arguments
                props.?ic.TabContainer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);

            % Auto-delete tabs when closed from the UI
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
            % > SELECTED returns the currently selected Tab, or empty.
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
            % > ADDTAB Add a new tab, returns [panel, tab].
            %
            % Example:
            %   [panel, tab] = tc.addTab("Home", Icon="home", Closable=true);
            %   panel.addChild(ic.Button(Label="Click me"));
            arguments
                this
                name (1,1) string = ""
                props.Closable (1,1) logical = false
                props.Disabled (1,1) logical = false
                props.Icon ic.asset.Asset = ic.asset.Asset.empty
            end

            idx = this.NextTabIndex;
            this.NextTabIndex = idx + 1;

            tabTarget = sprintf("tab-%d", idx);
            panelTarget = sprintf("panel-%d", idx);

            % Build Tab
            tabProps = struct();
            tabProps.ID = this.ID + "-tab-" + idx;
            tabProps.Label = name;
            if isfield(props, 'Closable'), tabProps.Closable = props.Closable; end
            if isfield(props, 'Disabled'), tabProps.Disabled = props.Disabled; end
            if isfield(props, 'Icon'), tabProps.Icon = props.Icon; end

            args = namedargs2cell(tabProps);
            tab = ic.tab.Tab(args{:});

            % Build TabPanel
            panel = ic.tab.TabPanel(ID = this.ID + "-panel-" + idx);

            % Link Tab → Panel
            tab.Panel = panel;

            % Register targets before adding children
            this.Targets = [this.Targets, tabTarget, panelTarget];
            this.addChild(tab, tabTarget);
            this.addChild(panel, panelTarget);

            % Listen for direct delete(tab) — clean up selection/targets
            addlistener(tab, 'ObjectBeingDestroyed', ...
                @(src, ~) this.handleTabDestroyed(src));

            % Auto-select first tab
            if this.SelectedTab == ""
                this.SelectedTab = tabTarget;
            end
        end

        function removeTab(this, tabOrTarget)
            % > REMOVETAB Remove and delete a tab from the container.
            %
            % Accepts a Tab handle or a target string ("tab-0").
            %
            % Example:
            %   tc.removeTab(tab);
            %   tc.removeTab("tab-2");
            arguments
                this
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

            % Find adjacent tab for re-selection
            tabs = this.Tabs;
            tabTargets = arrayfun(@(t) t.Target, tabs);
            pos = find(tabTargets == target, 1);

            % Guard and delete
            this.IsRemovingTab = true;
            delete(tab);
            if isvalid(panel), delete(panel); end
            this.IsRemovingTab = false;

            % Remove both targets
            this.Targets(this.Targets == target | ...
                         this.Targets == panelTarget) = [];

            % Adjust selection: prefer previous tab, fall back to first
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
            % > SELECTTAB Programmatically select a tab.
            %
            % Example:
            %   tc.selectTab(t2);
            arguments
                this
                tab (1,1) ic.tab.Tab
            end
            this.SelectedTab = tab.Target;
        end
    end

    methods (Access = public)
        function validateChild(this, child, target)
            % > VALIDATECHILD only Tab and TabPanel allowed as children
            assert(isa(child, "ic.tab.Tab") || isa(child, "ic.tab.TabPanel"), ...
                "ic:TabContainer:InvalidChild", ...
                "TabContainer only accepts Tab and TabPanel children. " + ...
                "Use tc.addTab() to create tabs.");

            validateChild@ic.core.ComponentContainer(this, child, target);
        end
    end

    methods (Access = private)
        function handleTabDestroyed(this, tab)
            % Called via ObjectBeingDestroyed listener on each Tab.
            %
            % Two cases:
            %   1. removeTab called delete → IsRemovingTab=true → skip.
            %   2. User called delete(tab) directly → clean up.
            if ~isvalid(this), return; end
            if this.IsRemovingTab, return; end

            target = tab.Target;
            panel = tab.Panel;
            wasSelected = (this.SelectedTab == target);

            % Find position before removing (for previous-tab selection)
            tabTargets = this.Targets(startsWith(this.Targets, "tab-"));
            pos = find(tabTargets == target, 1);

            % Remove panel
            if ~isempty(panel) && isvalid(panel)
                panelTarget = panel.Target;
                delete(panel);
                this.Targets(this.Targets == panelTarget) = [];
            end

            % Remove tab target
            this.Targets(this.Targets == target) = [];

            % Adjust selection: prefer previous tab
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
            % > FINDTABBYTARGET look up a Tab child by its target string.
            tabs = this.Tabs;
            mask = arrayfun(@(t) t.Target == target, tabs);
            idx = find(mask, 1);
            assert(~isempty(idx), "ic:TabContainer:TabNotFound", ...
                "No tab with target '%s'", target);
            tab = tabs(idx);
        end
    end
end
