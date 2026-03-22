classdef Monitor < ic.tp.Blade
    % > MONITOR Read-only value display blade for TweakPane.
    %
    % Push values from MATLAB via the Value property. Tweakpane renders
    % the value as text or a scrolling graph depending on the View prop.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE the monitored value (number, string, or boolean)
        Value = 0
        % > VIEW display mode: "text" or "graph"
        View (1,1) string {mustBeMember(View, ["text", "graph"])} = "text"
        % > GRAPHMIN minimum for graph view
        GraphMin (1,1) double = -1
        % > GRAPHMAX maximum for graph view
        GraphMax (1,1) double = 1
        % > BUFFERSIZE number of samples in graph buffer
        BufferSize (1,1) double = 64
        % > INTERVAL update interval in milliseconds
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
