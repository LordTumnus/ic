classdef Gain < ic.node.Node
    % > GAIN Triangle amplifier node — multiplies the input by Factor.
    %   Dynamically mirrors the input port's type on the output port.
    %   Signal inputs: output expression = "(Factor)*(srcExpression)"
    %   Flow inputs: converted to signal as Dirac impulse × Factor
    %   Static inputs: output is static (pass-through)
    %
    %   g = ic.node.Gain(Factor=2.5)
    %   g = ic.node.Gain(Label="Amplifier", Factor=0.5)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the node
        Label (1,1) string = ""

        % > FACTOR gain multiplier
        Factor (1,1) double = 1
    end

    methods
        function this = Gain(props)
            % > GAIN Construct a gain node.
            arguments
                props.?ic.node.Gain
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.Factor(this, val)
            this.Factor = val;
            this.syncOutput();
        end

        function onPortEdgeChanged(this, port)
            % > ONPORTEDGECHANGED Called by Port when edges connect/disconnect.
            if port.Name == "in"
                this.syncOutput();
            end
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("in", MaxConnections=1), "inputs");
            this.addPort(ic.node.Port("out"), "outputs");
            this.outputStatic("out");
        end
    end

    methods (Access = private)
        function syncOutput(this)
            % > SYNCOUTPUT Mirror input port type on output, applying gain.
            try
                inPort  = this.findPort("in",  "inputs");
                outPort = this.findPort("out", "outputs");
            catch
                return
            end

            oldType = outPort.Type;

            if isempty(inPort.Edges) || ~isvalid(inPort.Edges(1))
                outPort.Type = "static";
            else
                srcPort = inPort.Edges(1).SourcePort;
                switch srcPort.Type
                    case "signal"
                        outPort.Type       = "signal";
                        outPort.Expression = "(" + string(this.Factor) ...
                            + ")*(" + srcPort.Expression + ")";
                        outPort.Frequency  = srcPort.Frequency;
                        outPort.Speed      = srcPort.Speed;
                    case "flow"
                        % Flow → signal: interpret as Dirac impulse train
                        outPort.Type = "signal";
                        rate = srcPort.OutputRate;
                        offset = srcPort.TimeOffset;
                        if offset > 0
                            impulse = "pulse((t-" + string(offset) ...
                                + ")*" + string(rate) + ",0.05)";
                        else
                            impulse = "pulse(t*" + string(rate) + ",0.05)";
                        end
                        outPort.Expression = "(" + string(this.Factor) ...
                            + ")*(" + impulse + ")";
                        outPort.Speed = srcPort.Speed;
                    case "static"
                        outPort.Type = "static";
                end
            end

            % Update existing output edges' Type in-place
            if outPort.Type ~= oldType
                edges = outPort.Edges;
                for ii = 1:numel(edges)
                    if isvalid(edges(ii))
                        edges(ii).Type = outPort.Type;
                    end
                end
            end
        end
    end
end
