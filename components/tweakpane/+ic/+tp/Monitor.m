classdef Monitor < ic.tp.Blade
    % read-only value display blade for TweakPane.
    % Push updates to the #ic.tp.Monitor.Value property to update the display

    properties (SetObservable, AbortSet, Description = "Reactive")
        % the monitored value (number, string, or boolean)
        Value = 0

        % display mode: "text" shows the current #ic.tp.Monitor.Value; "graph" shows a scrolling history plot whose last value updates at a constant polling #ic.tp.Monitor.Interval
        View (1,1) string {mustBeMember(View, ["text", "graph"])} = "text"

        % minimum of the graph y-axis (only applies when #ic.tp.Monitor.View is "graph")
        GraphMin (1,1) double = -1

        % maximum of the graph y-axis (only applies when #ic.tp.Monitor.View is "graph")
        GraphMax (1,1) double = 1

        % number of samples retained in the graph buffer (only applies when #ic.tp.Monitor.View is "graph")
        BufferSize (1,1) double = 64

        % polling interval in milliseconds for updating the graph (only applies when #ic.tp.Monitor.View is "graph")
        Interval (1,1) double = 200
    end

    methods
        function this = Monitor(props)
            arguments
                props.?ic.tp.Monitor
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end
