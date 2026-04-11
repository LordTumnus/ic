classdef FeatureGroup < ic.map.Layer & ic.core.Container
    % groups map layers with shared event propagation and bounds calculation.
    % Like LayerGroup but additionally supports a bubbled Click event and
    % a fitBounds method that zooms to the group's extent.

    events (Description = "Reactive")
        % fires when any child feature in the group is clicked
        % {payload}
        % latlng | 1x2 double: [lat, lng] of the click
        % {/payload}
        Click
    end

    methods (Description = "Reactive")
        function out = fitBounds(this)
            % zoom the map to fit all features in this group
            out = this.publish("fitBounds", []);
        end
    end

    properties (Access = private, Hidden)
        % monotonic counter for stable child ordering
        NextLayerIndex (1,1) double = 0
    end

    methods
        function this = FeatureGroup(props)
            arguments
                props.?ic.map.FeatureGroup
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end

        function delete(this)
            delete@ic.core.Container(this);
            delete@ic.core.Component(this);
        end
    end

    methods (Access = public)
        function queue = flush(this)
            queue = flush@ic.mixin.Publishable(this);
            for ii = 1:numel(this.Children)
                this.Children(ii).flush();
            end
        end

        function layer = addMarker(this, props)
            % add a point marker to this group
            % {returns} the new #ic.map.Marker {/returns}
            arguments
                this
                props.?ic.map.Marker
            end
            args = namedargs2cell(props);
            layer = ic.map.Marker(args{:});
            this.insertLayer(layer);
        end

        function layer = addPolyline(this, props)
            % add a line path to this group
            % {returns} the new #ic.map.Polyline {/returns}
            arguments
                this
                props.?ic.map.Polyline
            end
            args = namedargs2cell(props);
            layer = ic.map.Polyline(args{:});
            this.insertLayer(layer);
        end

        function layer = addPolygon(this, props)
            % add a closed polygon to this group
            % {returns} the new #ic.map.Polygon {/returns}
            arguments
                this
                props.?ic.map.Polygon
            end
            args = namedargs2cell(props);
            layer = ic.map.Polygon(args{:});
            this.insertLayer(layer);
        end

        function layer = addCircle(this, props)
            % add a circle with radius in meters to this group
            % {returns} the new #ic.map.Circle {/returns}
            arguments
                this
                props.?ic.map.Circle
            end
            args = namedargs2cell(props);
            layer = ic.map.Circle(args{:});
            this.insertLayer(layer);
        end

        function layer = addRectangle(this, props)
            % add an axis-aligned rectangle to this group
            % {returns} the new #ic.map.Rectangle {/returns}
            arguments
                this
                props.?ic.map.Rectangle
            end
            args = namedargs2cell(props);
            layer = ic.map.Rectangle(args{:});
            this.insertLayer(layer);
        end

        function layer = addDivMarker(this, props)
            % add a custom HTML marker to this group
            % {returns} the new #ic.map.DivMarker {/returns}
            arguments
                this
                props.?ic.map.DivMarker
            end
            args = namedargs2cell(props);
            layer = ic.map.DivMarker(args{:});
            this.insertLayer(layer);
        end

        function layer = addPopup(this, props)
            % add a standalone popup to this group
            % {returns} the new #ic.map.Popup {/returns}
            arguments
                this
                props.?ic.map.Popup
            end
            args = namedargs2cell(props);
            layer = ic.map.Popup(args{:});
            this.insertLayer(layer);
        end

        function layer = addTooltip(this, props)
            % add a standalone tooltip to this group
            % {returns} the new #ic.map.Tooltip {/returns}
            arguments
                this
                props.?ic.map.Tooltip
            end
            args = namedargs2cell(props);
            layer = ic.map.Tooltip(args{:});
            this.insertLayer(layer);
        end

        function layer = addLayerGroup(this, props)
            % add a nested layer group
            % {returns} the new #ic.map.LayerGroup {/returns}
            arguments
                this
                props.?ic.map.LayerGroup
            end
            args = namedargs2cell(props);
            layer = ic.map.LayerGroup(args{:});
            this.insertLayer(layer);
        end

        function layer = addFeatureGroup(this, props)
            % add a nested feature group
            % {returns} the new #ic.map.FeatureGroup {/returns}
            arguments
                this
                props.?ic.map.FeatureGroup
            end
            args = namedargs2cell(props);
            layer = ic.map.FeatureGroup(args{:});
            this.insertLayer(layer);
        end
    end

    methods (Access = protected)
        function insertLayer(this, layer)
            idx = this.NextLayerIndex;
            this.NextLayerIndex = idx + 1;
            layer.LayerIndex = idx;
            this.addChild(layer);
        end
    end
end
