classdef SignalEdge < ic.node.Edge
    % > SIGNALEDGE Waveform edge — animated signal traveling from source to target.
    %
    %   Waveform shape, frequency, and speed are controlled by the source
    %   port's Expression, Frequency, and Speed properties. The edge controls
    %   only display: amplitude, color, and stroke width.
    %
    %   e = ic.node.SignalEdge()
    %   e = ic.node.SignalEdge(Color="#22c55e", Amplitude=10)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > AMPLITUDE perpendicular displacement in pixels (half peak-to-peak)
        Amplitude (1,1) double {mustBePositive} = 8

        % > COLOR waveform stroke color (empty = --ic-primary)
        Color (1,1) string = ""

        % > STROKEWIDTH waveform line width in pixels
        StrokeWidth (1,1) double {mustBePositive} = 2
    end

    methods
        function this = SignalEdge(props)
            % > SIGNALEDGE Construct a signal edge.
            arguments
                props.?ic.node.SignalEdge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Edge(props);
        end

        function copyDisplayProps(this, source)
            this.Amplitude = source.Amplitude;
            this.Color = source.Color;
            this.StrokeWidth = source.StrokeWidth;
        end
    end
end
