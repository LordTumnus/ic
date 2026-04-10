classdef (Abstract) Path < ic.map.Layer
    % abstract base for vector shapes (polylines, polygons, circles, rectangles).
    % Provides shared stroke and fill styling properties.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % stroke color as a CSS color string
        Color (1,1) string = "#3388ff"

        % stroke width in pixels
        Weight (1,1) double = 3

        % dash pattern as a CSS dash-array string (e.g. "10 5"), or empty for solid
        DashArray (1,1) string = ""

        % shape of the line ends
        LineCap (1,1) string {mustBeMember(LineCap, ["round", "butt", "square"])} = "round"

        % shape of the line joins
        LineJoin (1,1) string {mustBeMember(LineJoin, ["round", "bevel", "miter"])} = "round"

        % whether the shape has a fill
        Fill (1,1) logical = false

        % fill color (defaults to Color if empty). Use rgba() for transparency.
        FillColor (1,1) string = ""
    end

    events (Description = "Reactive")
        % fires when the user clicks the shape
        % {payload}
        % latlng | 1x2 double: [lat, lng] of the click point
        % {/payload}
        Click
    end

    methods
        function this = Path(props)
            this@ic.map.Layer(props);
        end
    end
end
