classdef SignalEdge < ic.node.Edge
    % > SIGNALEDGE Waveform edge — animated signal traveling from source to target.
    %
    %   Waveform shape, frequency, and speed are controlled by the source
    %   port's Expression, Frequency, and Speed properties. The edge controls
    %   only display: amplitude, signal color, and signal thickness.
    %   Stroke color and thickness from the base Edge class apply to the
    %   guide line.
    %
    %   e = ic.node.SignalEdge()
    %   e = ic.node.SignalEdge(SignalColor="#22c55e", Amplitude=10)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > AMPLITUDE perpendicular displacement in pixels (half peak-to-peak)
        Amplitude (1,1) double {mustBePositive} = 8

        % > SIGNALCOLOR waveform stroke color (empty = --ic-primary)
        SignalColor (1,1) string = ""

        % > SIGNALTHICKNESS waveform line width in pixels
        SignalThickness (1,1) double {mustBePositive} = 2
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
            this.SignalColor = source.SignalColor;
            this.SignalThickness = source.SignalThickness;
        end
    end
end
