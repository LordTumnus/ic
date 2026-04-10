classdef Marker < ic.map.Layer
    % point marker on a Leaflet map with optional popup and tooltip.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % marker position as [lat, long]
        Position (1,2) double = [0, 0]

        % whether the marker can be dragged by the user
        Draggable (1,1) logical = false

        % hover title (native browser tooltip)
        Title (1,1) string = ""

        % HTML content shown in a popup when the marker is clicked
        PopupContent (1,1) string = ""

        % HTML content shown in a tooltip on hover
        TooltipContent (1,1) string = ""

        % marker icon as a built-in name or custom image via ic.Asset.
        %
        % Built-in icons:
        %  - "pin"       - classic map pin (default)
        %  - "dot"       - filled circle
        %  - "square"    - filled square
        %  - "diamond"   - rotated square
        %  - "star"      - five-pointed star
        %  - "flag"      - small flag
        %  - "cross"     - crosshair
        %  - "triangle"  - pointing up
        %
        % Custom icons: pass an ic.Asset with a .png or .svg file.
        Icon ic.Asset = ic.Asset("")

        % marker icon size as [width, height] in pixels
        IconSize (1,2) double = [25, 41]

        % pixel offset from the top-left of the icon to the anchor point (tip). default: center-bottom.
        IconAnchor (1,2) double = [0, 0]

        % marker opacity (0 to 1)
        Opacity (1,1) double = 1.0
    end

    events (Description = "Reactive")
        % fires when the user clicks the marker
        % {payload}
        % latlng | 1x2 double: [lat, lng] of the marker
        % {/payload}
        Click

        % fires when the user starts dragging the marker
        % {payload}
        % latlng | 1x2 double: [lat, lng] at drag start
        % {/payload}
        DragStart

        % fires when the user finishes dragging the marker
        % {payload}
        % latlng | 1x2 double: [lat, lng] of the new position
        % {/payload}
        DragEnd
    end

    methods (Description = "Reactive")
        function out = openPopup(this)
            % programmatically open the bound popup
            out = this.publish("openPopup", []);
        end

        function out = closePopup(this)
            % programmatically close the bound popup
            out = this.publish("closePopup", []);
        end

        function out = openTooltip(this)
            % programmatically open the bound tooltip
            out = this.publish("openTooltip", []);
        end
    end

    methods
        function this = Marker(props)
            arguments
                props.?ic.map.Marker
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end
    end
end
