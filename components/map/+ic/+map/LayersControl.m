classdef LayersControl < ic.map.Control
    % layer visibility toggle panel displayed on the map.
    % Shows a button that reveals a list of registered layers with
    % visibility toggles. Hover the button to see the layer list.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether the layer list starts collapsed (hover to expand)
        Collapsed (1,1) logical = true

        % names of TileLayers for radio selection (mutually exclusive)
        BaseLayers (:,1) string = string.empty

        % names of groups/layers for checkbox toggle (independent)
        OverlayLayers (:,1) string = string.empty
    end

    events (Description = "Reactive")
        % fires when the layer panel is opened (on hover)
        Opened

        % fires when the layer panel is closed (mouse leaves)
        Closed

        % fires when a layer's visibility is toggled
        % {payload}
        % name  | string: the Name of the toggled layer
        % visible | logical: new visibility state
        % group | string: "base" or "overlay"
        % {/payload}
        LayerToggled
    end

    methods
        function this = LayersControl(props)
            arguments
                props.?ic.map.LayersControl
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Control(props);
            if ~any(strcmp(fieldnames(props), 'Position'))
                this.Position = "topright";
            end
        end
    end
end
