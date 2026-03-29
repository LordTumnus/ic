classdef TileLayout < ic.core.ComponentContainer
    % tiling tab layout with draggable split areas.
    % A VSCode-style layout where tabs can be dragged to edges to create new split areas. Each area is a tab group with its own selection.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % size of the resize gutter between groups, in pixels
        GutterSize (1,1) double = 3

        % dimension of the tab headers relative to the component font size
        Size (1,1) string {mustBeMember(Size, ...
            ["sm", "md", "lg"])} = "sm"

        % whether all interactions are disabled
        Disabled (1,1) logical = false

        % whether tabs can be dragged between groups
        DragEnabled (1,1) logical = true
    end

    properties (Dependent, SetAccess = private)
        % array of #ic.tab.Tab children
        Tabs

        % array of #ic.tab.TabPanel children
        Panels
    end

    properties (Access = private)
        % monotonic counter
        NextTabIndex (1,1) double = 0

        % guard flag: prevents handleTabDestroyed from duplicating
        % cleanup that removeTab already handles.
        IsRemovingTab (1,1) logical = false
    end

    events (Description = "Reactive")
        % fires when a tab's close button is clicked. The tab is automatically deleted after this event
        % {payload}
        % value | char: target string of the closed tab
        % {/payload}
        TabClosed

        % fires when a tab is moved between groups via drag-and-drop
        % {payload}
        % value | struct: struct with fields 'tab' (char), 'fromGroup' (char), and 'toGroup' (char)
        % {/payload}
        TabMoved

        % fires on any layout change (split, merge, resize, or move)
        % {payload}
        % value | char: JSON string representing the current split tree
        % {/payload}
        LayoutChanged
    end

    methods
        function this = TileLayout(props)
            arguments
                props.?ic.TileLayout
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

        function [panel, tab] = addTab(this, name, props)
            % add a new tab to the layout.
            % {returns} the #ic.tab.TabPanel (content area) and #ic.tab.Tab (header) {/returns}
            % {example}
            %   tl = ic.TileLayout();
            %   [panel, tab] = tl.addTab("Home", Icon="home", Closable=true);
            %   panel.addChild(ic.Button(Label="Click me"));
            % {/example}
            arguments
                this
                % name of the new tab
                name (1,1) string = ""
                % whether the tab is closable
                props.Closable (1,1) logical = false
                % whether the tab is disabled
                props.Disabled (1,1) logical = false
                % optional icon for the tab header
                props.Icon ic.Asset = ic.Asset.empty
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

            % Listen for direct delete(tab) and clean up selection/targets
            addlistener(tab, 'ObjectBeingDestroyed', ...
                @(src, ~) this.handleTabDestroyed(src));
        end

        function removeTab(this, tabOrTarget)
            % remove and delete a tab from the layout.
            % Accepts a Tab handle or a target string (e.g. "tab-0").
            arguments
                this
                % tab handle or target string of the tab to remove
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

            % guard and delete
            this.IsRemovingTab = true;
            delete(tab);
            if isvalid(panel), delete(panel); end
            this.IsRemovingTab = false;

            % remove both targets
            this.Targets(this.Targets == target | ...
                         this.Targets == panelTarget) = [];
        end
    end

    methods (Hidden)
        function validateChild(this, child, target)
            assert(isa(child, "ic.tab.Tab") || isa(child, "ic.tab.TabPanel"), ...
                "ic:TileLayout:InvalidChild", ...
                "TileLayout only accepts Tab and TabPanel children. " + ...
                "Use tl.addTab() to create tabs.");

            validateChild@ic.core.ComponentContainer(this, child, target);
        end
    end

    methods (Access = private)
        function handleTabDestroyed(this, tab)
            if ~isvalid(this), return; end
            if this.IsRemovingTab, return; end

            target = tab.Target;
            panel = tab.Panel;

            % remove panel
            if ~isempty(panel) && isvalid(panel)
                panelTarget = panel.Target;
                delete(panel);
                this.Targets(this.Targets == panelTarget) = [];
            end

            % remove tab target
            this.Targets(this.Targets == target) = [];
        end

        function tab = findTabByTarget(this, target)
            tabs = this.Tabs;
            mask = arrayfun(@(t) t.Target == target, tabs);
            idx = find(mask, 1);
            assert(~isempty(idx), "ic:TileLayout:TabNotFound", ...
                "No tab with target '%s'", target);
            tab = tabs(idx);
        end
    end
end
