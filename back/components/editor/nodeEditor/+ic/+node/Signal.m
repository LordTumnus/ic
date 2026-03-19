classdef Signal < ic.node.Node
    % > SIGNAL Oscilloscope source node with embedded waveform preview.
    %   The Expression is a JS math expression (expr-eval syntax) evaluated
    %   as f(t). The same expression drives both the preview graph and the
    %   signal-type output port waveform overlay on connected edges.
    %
    %   sig = ic.node.Signal(Expression="sin(2*pi*t)", PreviewTime=3)
    %   sig = ic.node.Signal(Label="LFO", Expression="0.5*sin(2*pi*t)+0.5*cos(4*pi*t)")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the node
        Label (1,1) string = ""

        % > EXPRESSION JS math expression f(t) — uses expr-eval syntax
        Expression (1,1) string = "sin(2*pi*t)"

        % > FREQUENCY cycles visible in the edge waveform overlay
        Frequency (1,1) double {mustBePositive} = 1

        % > PREVIEWTIME x-axis range in seconds for the preview graph
        PreviewTime (1,1) double {mustBePositive} = 2
    end

    methods
        function this = Signal(props)
            % > SIGNAL Construct a signal source node.
            arguments
                props.?ic.node.Signal
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.Expression(this, val)
            this.Expression = val;
            this.syncSignalPort();
        end

        function set.Frequency(this, val)
            this.Frequency = val;
            this.syncSignalPort();
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("signal"), "outputs");
            this.outputSignal("signal", ...
                Expression=this.Expression, ...
                Frequency=this.Frequency);
        end
    end

    methods (Access = private)
        function syncSignalPort(this)
            % > SYNCSIGNALPORT Propagate Expression/Frequency to the output port.
            try
                port = this.findPort("signal", "outputs");
            catch
                return  % Port not yet created (during construction)
            end
            port.Expression = this.Expression;
            port.Frequency = this.Frequency;
        end
    end
end
