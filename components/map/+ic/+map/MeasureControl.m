classdef MeasureControl < ic.map.Control
    % measurement tool for distances and areas on the map.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % measurement units
        Units (1,1) string {mustBeMember(Units, ["metric", "imperial"])} = "metric"

        % measurement line color (empty string uses theme primary)
        Color (1,1) string = ""

        % measurement line weight in pixels
        Weight (1,1) double = 2
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % current measurement result (synced from frontend)
        ActiveMeasurement struct = struct()
    end

    events (Description = "Reactive")
        % fires when the user begins a measurement
        MeasureStart

        % fires when a measurement is completed
        MeasureEnd
    end

    methods (Description = "Reactive")
        function out = clear(this)
            % clear the current measurement from the map
            out = this.publish("clear", []);
        end
    end

    methods
        function this = MeasureControl(props)
            arguments
                props.?ic.map.MeasureControl
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.map.Control(props);
            if ~any(strcmp(fieldnames(props), 'Position'))
                this.Position = "topright";
            end
        end
    end
end
