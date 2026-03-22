classdef Accordion < ic.core.ComponentContainer
    % > ACCORDION Collapsible panel container with expandable sections.
    %
    % Each section is an AccordionPanel with its own Label, Icon, and
    % Open state. Panels are added via addPanel() and hold child
    % components in their default slot.
    %
    % Example:
    %   acc = ic.Accordion(Multiple=false, Size="md");
    %   p1 = acc.addPanel("General", Icon="settings");
    %   p1.addChild(ic.InputText(Label="Name"));
    %
    %   p2 = acc.addPanel("Advanced", Icon="sliders");
    %   p2.addChild(ic.Slider(Label="Speed"));
    %
    %   p1.Open = true;
    %   addlistener(acc, 'PanelToggled', @(~, e) disp(e.Data));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > MULTIPLE allow multiple panels open simultaneously
        Multiple (1,1) logical = true

        % > SIZE header size: 'sm', 'md', or 'lg'
        Size (1,1) string {mustBeMember(Size, ...
            ["sm", "md", "lg"])} = "md"

        % > DISABLED disable all panel interactions when true
        Disabled (1,1) logical = false
    end

    properties (Dependent, SetAccess = private)
        % > PANELS array of AccordionPanel children (read-only)
        Panels
    end

    properties (Access = private)
        % Monotonic counter — never decremented, ensures unique targets
        NextPanelIndex (1,1) double = 0

        % Guard flag: prevents handlePanelDestroyed from duplicating
        % cleanup that removePanel already handles.
        IsRemovingPanel (1,1) logical = false
    end

    events (Description = "Reactive")
        % > PANELTOGGLED fires when a panel is opened or closed from the UI
        PanelToggled
    end

    methods
        function this = Accordion(props)
            % > ACCORDION Create an accordion container.
            arguments
                props.?ic.Accordion
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end

        function panels = get.Panels(this)
            if isempty(this.Children)
                panels = ic.accordion.AccordionPanel.empty();
            else
                mask = arrayfun(@(c) isa(c, 'ic.accordion.AccordionPanel'), ...
                    this.Children);
                panels = this.Children(mask);
            end
        end

        function panel = addPanel(this, name, props)
            % > ADDPANEL Add a new panel, returns the AccordionPanel.
            %
            % Example:
            %   p = acc.addPanel("General", Icon="settings", Open=true);
            %   p.addChild(ic.InputText(Label="Name"));
            arguments
                this
                name (1,1) string = ""
                props.Open (1,1) logical = false
                props.Disabled (1,1) logical = false
                props.Icon ic.asset.Asset = ic.asset.Asset.empty
            end

            idx = this.NextPanelIndex;
            this.NextPanelIndex = idx + 1;

            panelTarget = sprintf("panel-%d", idx);

            % Build AccordionPanel
            panelProps = struct();
            panelProps.ID = this.ID + "-panel-" + idx;
            panelProps.Label = name;
            if isfield(props, 'Open'), panelProps.Open = props.Open; end
            if isfield(props, 'Disabled'), panelProps.Disabled = props.Disabled; end
            if isfield(props, 'Icon'), panelProps.Icon = props.Icon; end

            args = namedargs2cell(panelProps);
            panel = ic.accordion.AccordionPanel(args{:});

            % Register target and add child
            this.Targets = [this.Targets, panelTarget];
            this.addChild(panel, panelTarget);

            % Listen for direct delete(panel) — clean up targets
            addlistener(panel, 'ObjectBeingDestroyed', ...
                @(src, ~) this.handlePanelDestroyed(src));
        end

        function removePanel(this, panelOrTarget)
            % > REMOVEPANEL Remove and delete a panel from the container.
            %
            % Accepts an AccordionPanel handle or a target string.
            %
            % Example:
            %   acc.removePanel(panel);
            %   acc.removePanel("panel-2");
            arguments
                this
                panelOrTarget
            end

            if isstring(panelOrTarget) || ischar(panelOrTarget)
                target = string(panelOrTarget);
                panel = this.findPanelByTarget(target);
            else
                panel = panelOrTarget;
                target = panel.Target;
            end

            % Guard and delete
            this.IsRemovingPanel = true;
            delete(panel);
            this.IsRemovingPanel = false;

            % Remove target
            this.Targets(this.Targets == target) = [];
        end

        function expandAll(this)
            % > EXPANDALL Open all panels.
            panels = this.Panels;
            for i = 1:numel(panels)
                panels(i).Open = true;
            end
        end

        function collapseAll(this)
            % > COLLAPSEALL Close all panels.
            panels = this.Panels;
            for i = 1:numel(panels)
                panels(i).Open = false;
            end
        end
    end

    methods (Access = public)
        function validateChild(this, child, target)
            % > VALIDATECHILD only AccordionPanel allowed as children
            assert(isa(child, "ic.accordion.AccordionPanel"), ...
                "ic:Accordion:InvalidChild", ...
                "Accordion only accepts AccordionPanel children. " + ...
                "Use acc.addPanel() to create panels.");

            validateChild@ic.core.ComponentContainer(this, child, target);
        end
    end

    methods (Access = private)
        function handlePanelDestroyed(this, panel)
            % Called via ObjectBeingDestroyed listener on each panel.
            if ~isvalid(this), return; end
            if this.IsRemovingPanel, return; end

            target = panel.Target;
            this.Targets(this.Targets == target) = [];
        end

        function panel = findPanelByTarget(this, target)
            % > FINDPANELBYTARGET look up a panel by its target string.
            panels = this.Panels;
            mask = arrayfun(@(p) p.Target == target, panels);
            idx = find(mask, 1);
            assert(~isempty(idx), "ic:Accordion:PanelNotFound", ...
                "No panel with target '%s'", target);
            panel = panels(idx);
        end
    end
end
