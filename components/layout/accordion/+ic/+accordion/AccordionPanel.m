classdef AccordionPanel < ic.core.ComponentContainer
    % collapsible content panel within an #ic.Accordion.
    % Holds the header configuration (label, icon and open state) and acts as a container for child components. Create panels via #ic.Accordion.addPanel, not directly.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % text displayed in the panel header
        Label (1,1) string = ""

        % icon displayed before the label
        Icon ic.Asset = ic.Asset.empty

        % whether the panel content is expanded
        Open (1,1) logical = false

        % whether the panel is disabled and cannot be toggled
        Disabled (1,1) logical = false
    end

    methods (Access = {?ic.Accordion})
        function this = AccordionPanel(props)
            arguments
                props.?ic.accordion.AccordionPanel
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end
