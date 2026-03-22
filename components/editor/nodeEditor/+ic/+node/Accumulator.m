classdef Accumulator < ic.node.Node
    % > ACCUMULATOR Summation node — sums N inputs and outputs the result.
    %   Accepts any edge type on each input. Output is a signal edge
    %   whose expression is the sum of all connected input expressions.
    %   Flow inputs are converted to Dirac impulse trains.
    %   Rendered as a Σ symbol with a counter display.
    %
    %   acc = ic.node.Accumulator(InputNumber=3)
    %   acc = ic.node.Accumulator(Label="Sum", InputNumber=4)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the accumulator
        Label (1,1) string = ""

        % > INPUTNUMBER number of input ports
        InputNumber (1,1) double {mustBePositive, mustBeInteger} = 2
    end

    methods
        function this = Accumulator(props)
            % > ACCUMULATOR Construct an accumulator node.
            arguments
                props.?ic.node.Accumulator
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.InputNumber(this, val)
            oldVal = this.InputNumber;
            this.InputNumber = val;
            this.syncInputPorts(oldVal, val);
        end

        function onPortEdgeChanged(this, port)
            % > ONPORTEDGECHANGED Called by Port when edges connect/disconnect.
            if startsWith(port.Name, "in")
                this.syncOutput();
            end
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            for ii = 1:this.InputNumber
                this.addPort(ic.node.Port("in" + ii, MaxConnections=1), "inputs");
            end
            this.addPort(ic.node.Port("out"), "outputs");
            this.outputStatic("out");
        end
    end

    methods (Access = private)
        function syncInputPorts(this, oldN, newN)
            % > SYNCINPUTPORTS Add or remove input ports to match InputNumber.
            try
                if newN > oldN
                    for ii = (oldN+1):newN
                        this.addPort(ic.node.Port("in" + ii, MaxConnections=1), "inputs");
                    end
                elseif newN < oldN
                    for ii = oldN:-1:(newN+1)
                        port = this.findPort("in" + ii, "inputs");
                        this.removePort(port);
                    end
                end
            catch
                return
            end
            this.syncOutput();
        end

        function syncOutput(this)
            % > SYNCOUTPUT Build sum expression from all connected inputs.
            try
                outPort = this.findPort("out", "outputs");
            catch
                return
            end

            oldType = outPort.Type;
            terms = strings(0);
            maxSpeed = 1;

            for ii = 1:this.InputNumber
                try
                    inPort = this.findPort("in" + ii, "inputs");
                catch
                    continue
                end
                if isempty(inPort.Edges) || ~isvalid(inPort.Edges(1))
                    continue
                end
                srcPort = inPort.Edges(1).SourcePort;
                switch srcPort.Type
                    case "signal"
                        terms(end+1) = "(" + srcPort.Expression + ")"; %#ok<AGROW>
                        maxSpeed = max(maxSpeed, srcPort.Speed);
                    case "flow"
                        rate = srcPort.OutputRate;
                        offset = srcPort.TimeOffset;
                        if offset > 0
                            terms(end+1) = "pulse((t-" + string(offset) ...
                                + ")*" + string(rate) + ",0.05)"; %#ok<AGROW>
                        else
                            terms(end+1) = "pulse(t*" + string(rate) ...
                                + ",0.05)"; %#ok<AGROW>
                        end
                        maxSpeed = max(maxSpeed, srcPort.Speed);
                end
            end

            if isempty(terms)
                outPort.Type = "static";
            else
                outPort.Type       = "signal";
                outPort.Expression = join(terms, "+");
                outPort.Speed      = maxSpeed;
            end

            % Propagate type change to output edges
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
