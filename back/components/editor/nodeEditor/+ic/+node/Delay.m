classdef Delay < ic.node.Node
    % > DELAY Time-shift node — delays the input signal/flow.
    %   Dynamically mirrors the input port's type on the output port.
    %   Signal inputs: output expression applies time offset t → (t - delay)
    %   Flow inputs: output mirrors flow with reduced speed
    %   Static inputs: pass-through (static has no temporal dimension)
    %
    %   d = ic.node.Delay(DelayTime=500, Unit="ms")
    %   d = ic.node.Delay(Label="Echo", DelayTime=1)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the node
        Label (1,1) string = ""

        % > DELAYTIME delay amount (interpreted according to Unit)
        DelayTime (1,1) double {mustBeNonnegative} = 1

        % > UNIT time unit: "s" (seconds) or "ms" (milliseconds)
        Unit (1,1) string {mustBeMember(Unit, ["s","ms"])} = "s"
    end

    methods
        function this = Delay(props)
            % > DELAY Construct a delay node.
            arguments
                props.?ic.node.Delay
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.DelayTime(this, val)
            this.DelayTime = val;
            this.syncOutput();
        end

        function set.Unit(this, val)
            this.Unit = val;
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
        function dur = getDelaySec(this)
            % > GETDELAYSEC Convert DelayTime + Unit to seconds.
            dur = this.DelayTime;
            if this.Unit == "ms"
                dur = dur / 1000;
            end
        end

        function syncOutput(this)
            % > SYNCOUTPUT Mirror input port type on output, applying delay.
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
                dur = this.getDelaySec();

                switch srcPort.Type
                    case "signal"
                        outPort.Type = "signal";
                        % Replace standalone 't' with '(t-delay)' in expression
                        delayed = regexprep(srcPort.Expression, ...
                            '(?<![a-zA-Z_])t(?![a-zA-Z_0-9])', ...
                            "(t-" + string(dur) + ")");
                        outPort.Expression = delayed;
                        outPort.Frequency = srcPort.Frequency;
                        outPort.Speed = srcPort.Speed;
                    case "flow"
                        outPort.Type = "flow";
                        outPort.OutputRate = srcPort.OutputRate;
                        % Slow down particles to visualize delay
                        outPort.Speed = srcPort.Speed / max(1, 1 + dur);
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
