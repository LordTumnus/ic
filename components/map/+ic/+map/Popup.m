classdef Popup < ic.map.Layer
    % standalone popup at a fixed geographic position on a Leaflet map.
    % Use for annotations, alerts, or information overlays that are not
    % bound to a specific marker.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % geographic position as [lat, lng]
        Position (1,2) double = [0, 0]

        % HTML content displayed inside the popup
        Content (1,1) string = ""

        % whether the popup is currently open
        IsOpen (1,1) logical = true

        % maximum width of the popup in pixels
        MaxWidth (1,1) double = 300

        % minimum width of the popup in pixels
        MinWidth (1,1) double = 50

        % whether clicking elsewhere on the map closes this popup
        AutoClose (1,1) logical = true
    end

    events (Description = "Reactive")
        % fires when the popup is closed by the user
        Closed
    end

    methods (Description = "Reactive")
        function out = open(this)
            % programmatically open the popup
            out = this.publish("open", []);
        end

        function out = close(this)
            % programmatically close the popup
            out = this.publish("close", []);
        end
    end

    methods
        function this = Popup(props)
            arguments
                props.?ic.map.Popup
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Layer(props);
        end
    end
end
