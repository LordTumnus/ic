classdef Accordion < ic.core.ComponentContainer
    % collapsible panel container with expandable sections.
    % Each section is an AccordionPanel with its own Label, Icon, and Open state. Panels are added via #ic.Accordion.addPanel and hold child components in their content area.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether multiple panels can be open at the same time. When false, opening a panel closes any other open panel
        Multiple (1,1) logical = true

        % dimension of the panel headers relative to the component font size
        Size (1,1) string {mustBeMember(Size, ...
            ["sm", "md", "lg"])} = "md"

        % whether all panel interactions are disabled
        Disabled (1,1) logical = false
    end

    properties (Dependent, SetAccess = private)
        % array of #ic.accordion.AccordionPanel children
        Panels
    end

    properties (Access = private)
        % monotonic counter
        NextPanelIndex (1,1) double = 0
    end

    events (Description = "Reactive")
        % fires when a panel is opened or closed by the user
        % {payload}
        % value | struct: struct with fields 'target' (char) and 'open' (logical)
        % {/payload}
        PanelToggled
    end

    methods
        function this = Accordion(props)
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
            % add a new panel to the accordion.
            % {returns} the created #ic.accordion.AccordionPanel {/returns}
            % {example}
            %   acc = ic.Accordion();
            %   p = acc.addPanel("General", Icon="settings", Open=true);
            %   p.addChild(ic.InputText(Placeholder="Name"));
            % {/example}
            arguments
                this
                % name of the new panel
                name (1,1) string = ""
                % whether the panel is open by default
                props.Open (1,1) logical = false
                % whether the panel is disabled
                props.Disabled (1,1) logical = false
                % optional icon for the panel header
                props.Icon ic.Asset = ic.Asset.empty
            end

            idx = this.NextPanelIndex;
            this.NextPanelIndex = idx + 1;

            % build AccordionPanel
            panelProps = struct();
            panelProps.ID = this.ID + "-panel-" + idx;
            panelProps.Label = name;
            if isfield(props, 'Open'), panelProps.Open = props.Open; end
            if isfield(props, 'Disabled'), panelProps.Disabled = props.Disabled; end
            if isfield(props, 'Icon'), panelProps.Icon = props.Icon; end

            args = namedargs2cell(panelProps);
            panel = ic.accordion.AccordionPanel(args{:});

            this.addChild(panel);
        end

        function removePanel(this, panelOrId)
            % remove and delete a panel from the accordion.
            % {example}
            %   acc.removePanel(p);
            % {/example}
            arguments
                this
                % #ic.accordion.AccordionPanel handle or panel ID string to remove
                panelOrId
            end

            if isstring(panelOrId) || ischar(panelOrId)
                panelId = string(panelOrId);
                panels = this.Panels;
                mask = arrayfun(@(p) p.ID == panelId, panels);
                idx = find(mask, 1);
                assert(~isempty(idx), "ic:Accordion:PanelNotFound", ...
                    "No panel with ID '%s'", panelId);
                panel = panels(idx);
            else
                panel = panelOrId;
            end

            delete(panel);
        end

        function expandAll(this)
            % open all panels
            panels = this.Panels;
            for i = 1:numel(panels)
                panels(i).Open = true;
            end
        end

        function collapseAll(this)
            % close all panels
            panels = this.Panels;
            for i = 1:numel(panels)
                panels(i).Open = false;
            end
        end
    end

    methods (Hidden)
        function validateChild(this, child)
            assert(isa(child, "ic.accordion.AccordionPanel"), ...
                "ic:Accordion:InvalidChild", ...
                "Accordion only accepts AccordionPanel children. " + ...
                "Use acc.addPanel() to create panels.");

            validateChild@ic.core.ComponentContainer(this, child);
        end
    end
end
