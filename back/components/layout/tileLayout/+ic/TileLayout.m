classdef TileLayout < ic.core.ComponentContainer
    % > TILELAYOUT Tiling tab layout with draggable split areas.
    %
    % A VSCode-style layout where tabs can be dragged to edges to create
    % new split areas. Each area is a tab group with its own selection.
    % The split tree is managed by the frontend; MATLAB manages tabs.
    %
    % Example:
    %   tl = ic.TileLayout(Size="sm");
    %   [p1, t1] = tl.addTab("Editor", Icon="code", Closable=true);
    %   p1.addChild(ic.CodeEditor(Language="matlab"));
    %
    %   [p2, t2] = tl.addTab("Console", Icon="terminal", Closable=true);
    %   p2.addChild(ic.Label(Text="Output"));
    %
    %   % Tabs are auto-deleted when closed from the UI.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > GUTTERSIZE size of resize gutter between groups (pixels)
        GutterSize (1,1) double = 3

        % > SIZE tab header size: 'sm', 'md', or 'lg'
        Size (1,1) string {mustBeMember(Size, ...
            ["sm", "md", "lg"])} = "sm"

        % > DISABLED disable all interactions when true
        Disabled (1,1) logical = false

        % > DRAGENABLED enable cross-group drag-and-drop
        DragEnabled (1,1) logical = true
    end

    properties (Dependent, SetAccess = private)
        % > TABS array of Tab children (read-only)
        Tabs

        % > PANELS array of TabPanel children (read-only)
        Panels
    end

    properties (Access = private)
        % Monotonic counter — never decremented, ensures unique targets
        NextTabIndex (1,1) double = 0

        % Guard flag: prevents handleTabDestroyed from duplicating
        % cleanup that removeTab already handles.
        IsRemovingTab (1,1) logical = false
    end

    events (Description = "Reactive")
        % > TABCLOSED fires when a tab's close button is clicked
        TabClosed

        % > TABMOVED fires when a tab is moved between groups
        TabMoved

        % > LAYOUTCHANGED fires on any layout change (split/merge/resize/move)
        LayoutChanged
    end

    methods
        function this = TileLayout(props)
            % > TILELAYOUT Create a tiling tab layout.
            arguments
                props.?ic.TileLayout
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

        function [panel, tab] = addTab(this, name, props)
            % > ADDTAB Add a new tab, returns [panel, tab].
            %
            % Example:
            %   [panel, tab] = tl.addTab("Home", Icon="home", Closable=true);
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
        end

        function removeTab(this, tabOrTarget)
            % > REMOVETAB Remove and delete a tab from the layout.
            %
            % Accepts a Tab handle or a target string ("tab-0").
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

            % Guard and delete
            this.IsRemovingTab = true;
            delete(tab);
            if isvalid(panel), delete(panel); end
            this.IsRemovingTab = false;

            % Remove both targets
            this.Targets(this.Targets == target | ...
                         this.Targets == panelTarget) = [];
        end
    end

    methods (Access = public)
        function validateChild(this, child, target)
            % > VALIDATECHILD only Tab and TabPanel allowed as children
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

            % Remove panel
            if ~isempty(panel) && isvalid(panel)
                panelTarget = panel.Target;
                delete(panel);
                this.Targets(this.Targets == panelTarget) = [];
            end

            % Remove tab target
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
