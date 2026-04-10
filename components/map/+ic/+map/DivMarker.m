classdef DivMarker < ic.map.Layer & ic.core.Container
    % custom HTML marker on a Leaflet map.
    % Can hold IC child components or raw HTML via the #ic.map.DivMarker.Content property. When children are present, HTML content is ignored in favor of the rendered child components.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % marker position as [lat, long]
        Position (1,2) double = [0, 0]

        % HTML markup for simple markers (ignored when IC children exist)
        Content (1,1) string = ""

        % additional CSS class name(s) for the marker container
        ClassName (1,1) string = ""

        % icon size as [width, height] in pixels; [0,0] means auto-size
        IconSize (1,2) double = [0, 0]

        % anchor point offset from the top-left corner in pixels
        IconAnchor (1,2) double = [0, 0]

        % marker opacity (0 to 1)
        Opacity (1,1) double = 1.0

        % HTML content shown in a popup when the marker is clicked
        PopupContent (1,1) string = ""

        % HTML content shown in a tooltip on hover
        TooltipContent (1,1) string = ""
    end

    events (Description = "Reactive")
        % fires when the user clicks the marker
        % {payload}
        % latlng | 1x2 double: [lat, lng] of the marker
        % {/payload}
        Click
    end

    properties (Access = private, Hidden)
        % monotonic counter for stable child ordering
        NextLayerIndex (1,1) double = 0
    end

    methods
        function this = DivMarker(props)
            arguments
                props.?ic.map.DivMarker
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end

        function delete(this)
            % delete all children first, then run component teardown.
            delete@ic.core.Container(this);
            delete@ic.core.Component(this);
        end
    end

    methods (Access = public)
        function queue = flush(this)
            % flush queued events for this component, then cascade into children.
            queue = flush@ic.mixin.Publishable(this);
            for ii = 1:numel(this.Children)
                this.Children(ii).flush();
            end
        end
    end

    methods (Access = protected)
        function insertLayer(this, layer)
            % assigns index and registers child
            idx = this.NextLayerIndex;
            this.NextLayerIndex = idx + 1;
            layer.LayerIndex = idx;
            this.addChild(layer);
        end
    end
end
