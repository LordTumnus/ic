classdef AccordionPanel < ic.core.ComponentContainer
    % > ACCORDIONPANEL Collapsible content panel within ic.Accordion.
    %
    % AccordionPanel holds the header configuration (Label, Icon, Open)
    % and acts as a container for child components. Users add children
    % to the panel returned by Accordion.addPanel().
    %
    % Example:
    %   acc = ic.Accordion();
    %   p = acc.addPanel("Settings", Icon="settings");
    %   p.addChild(ic.InputText(Label="Name"));
    %   p.Open = true;

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed in the panel header
        Label (1,1) string = ""

        % > ICON icon displayed before the label (Lucide name, .svg file, or URL)
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % > OPEN whether the panel content is expanded
        Open (1,1) logical = false

        % > DISABLED whether the panel header is disabled (cannot be toggled)
        Disabled (1,1) logical = false
    end

    methods (Access = {?ic.Accordion})
        function this = AccordionPanel(props)
            arguments
                props.?ic.accordion.AccordionPanel
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = "default";
        end
    end
end
