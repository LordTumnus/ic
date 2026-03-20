classdef Switch < ic.node.Node
    % > SWITCH Electrical switch node — selects between two inputs.
    %   Three input ports: "ctrl" (top), "in1" (top-left), "in2" (bottom-left).
    %   One output port: "out" (right).
    %   When control signal >= 1, selects in1; otherwise selects in2.
    %   Output mirrors the type and properties of the selected input.
    %
    %   sw = ic.node.Switch(Label="Selector")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the switch
        Label (1,1) string = ""
    end

    methods
        function this = Switch(props)
            % > SWITCH Construct a switch node.
            arguments
                props.?ic.node.Switch
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function onPortEdgeChanged(this, port)
            % > ONPORTEDGECHANGED Called by Port when edges connect/disconnect.
            if ismember(port.Name, ["ctrl", "in1", "in2"])
                this.syncOutput();
            end
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("ctrl", MaxConnections=1), "inputs");
            this.addPort(ic.node.Port("in1", MaxConnections=1), "inputs");
            this.addPort(ic.node.Port("in2", MaxConnections=1), "inputs");
            this.addPort(ic.node.Port("out"), "outputs");
            this.outputStatic("out");
        end
    end

    methods (Access = private)
        function syncOutput(this)
            % > SYNCOUTPUT Build sel(ctrl, in1, in2) expression on output.
            try
                outPort  = this.findPort("out", "outputs");
                ctrlPort = this.findPort("ctrl", "inputs");
                in1Port  = this.findPort("in1", "inputs");
                in2Port  = this.findPort("in2", "inputs");
            catch
                return
            end

            % Resolve each input to an expression string
            ctrlExpr = resolvePortExpr(ctrlPort);
            in1Expr  = resolvePortExpr(in1Port);
            in2Expr  = resolvePortExpr(in2Port);

            % Determine max speed from all connected inputs
            maxSpeed = 1;
            for p = [ctrlPort, in1Port, in2Port]
                if ~isempty(p.Edges) && isvalid(p.Edges(1))
                    maxSpeed = max(maxSpeed, p.Edges(1).SourcePort.Speed);
                end
            end

            % Build output expression
            if ctrlExpr ~= "" && (in1Expr ~= "" || in2Expr ~= "")
                if in1Expr == "", in1Expr = "0"; end
                if in2Expr == "", in2Expr = "0"; end
                outPort.Type       = "signal";
                outPort.Expression = "sel(" + ctrlExpr + "," + in1Expr + "," + in2Expr + ")";
                outPort.Speed      = maxSpeed;
            elseif in1Expr ~= ""
                outPort.Type       = "signal";
                outPort.Expression = in1Expr;
                outPort.Speed      = maxSpeed;
            elseif in2Expr ~= ""
                outPort.Type       = "signal";
                outPort.Expression = in2Expr;
                outPort.Speed      = maxSpeed;
            else
                outPort.Type       = "static";
                outPort.Expression = "0";
            end
        end
    end
end

function expr = resolvePortExpr(port)
    % Resolve a port's connected source to an expression string.
    expr = "";
    if isempty(port.Edges) || ~isvalid(port.Edges(1))
        return
    end
    src = port.Edges(1).SourcePort;
    switch src.Type
        case "signal"
            expr = src.Expression;
        case "flow"
            r = src.OutputRate;
            o = src.TimeOffset;
            if o > 0
                expr = "pulse((t-" + string(o) + ")*" + string(r) + ",0.05)";
            else
                expr = "pulse(t*" + string(r) + ",0.05)";
            end
    end
end
