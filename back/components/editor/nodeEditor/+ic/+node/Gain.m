classdef Gain < ic.node.Node
    % > GAIN Triangle amplifier node — multiplies the input by Factor.
    %   Dynamically mirrors the input port's type on the output port.
    %   Signal inputs: output expression = "(Factor)*(srcExpression)"
    %   Flow inputs: output mirrors flow properties (speed, rate)
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
            %   After updating the port, reconnects downstream edges so the
            %   MATLAB edge class matches the new port type.
            try
                inPort = this.findPort("in", "inputs");
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
                        outPort.Type = "signal";
                        outPort.Expression = "(" + string(this.Factor) ...
                            + ")*(" + srcPort.Expression + ")";
                        outPort.Frequency = srcPort.Frequency;
                        outPort.Speed = srcPort.Speed;
                    case "flow"
                        outPort.Type = "flow";
                        outPort.Speed = srcPort.Speed;
                        outPort.OutputRate = srcPort.OutputRate;
                    case "static"
                        outPort.Type = "static";
                end
            end

            % If type changed, reconnect downstream edges with correct class
            if outPort.Type ~= oldType
                this.reconnectOutputEdges(outPort);
            end
        end

        function reconnectOutputEdges(this, outPort)
            % > RECONNECTOUTPUTEDGES Delete and recreate output edges so
            %   the MATLAB edge class matches the current port type.
            editor = this.Parent;
            if isempty(editor) || ~isvalid(editor)
                return
            end

            % Snapshot targets before deleting (iterate backwards)
            targets = struct('node', {}, 'port', {});
            edges = outPort.Edges;
            for ii = numel(edges):-1:1
                e = edges(ii);
                if ~isvalid(e), continue; end
                targets(end+1) = struct( ...
                    'node', e.TargetNode, ...
                    'port', e.TargetPortName); %#ok<AGROW>
                editor.removeEdge(e);
            end

            % Recreate with current port type
            for ii = 1:numel(targets)
                t = targets(ii);
                if isvalid(t.node)
                    this.connect(t.node, outPort.Name, t.port);
                end
            end
        end
    end
end
