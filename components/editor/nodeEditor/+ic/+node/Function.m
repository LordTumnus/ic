classdef Function < ic.node.Node
    % > FUNCTION f(in1,in2,...) — combines N inputs via a single expression.
    %   Unlike Transform (which applies the same expression to each channel
    %   independently), Function lets the expression reference all inputs
    %   by name: in1, in2, in3, etc.  The result goes to a single output.
    %
    %   fn = ic.node.Function(Expression="in1 + in2", InputNumber=2)
    %   fn = ic.node.Function(Label="Mix", Expression="0.5*in1 + 0.5*in2", InputNumber=2)
    %   fn = ic.node.Function(Expression="in1 * in2 + in3", InputNumber=3)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL header text
        Label (1,1) string = "Function"

        % > EXPRESSION output expression referencing in1, in2, ... (e.g. "in1 + in2")
        Expression (1,1) string = ""

        % > COLOR accent color (empty = theme default)
        Color (1,1) string = ""

        % > ICON header icon
        Icon ic.Asset = ic.Asset.empty

        % > INPUTNUMBER number of input ports
        InputNumber (1,1) double {mustBePositive, mustBeInteger} = 2
    end

    methods
        function this = Function(props)
            % > FUNCTION Construct a function node.
            arguments
                props.?ic.node.Function
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.InputNumber(this, val)
            oldVal = this.InputNumber;
            this.InputNumber = val;
            this.syncInputPorts(oldVal, val);
        end

        function set.Expression(this, val)
            this.Expression = val;
            this.syncOutput();
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
            % > SYNCOUTPUT Build combined expression from all connected inputs.
            try
                outPort = this.findPort("out", "outputs");
            catch
                return
            end

            oldType = outPort.Type;
            expr = this.Expression;
            hasAnyInput = false;
            maxSpeed = 1;

            for ii = 1:this.InputNumber
                try
                    inPort = this.findPort("in" + ii, "inputs");
                catch
                    continue
                end

                varName = "in" + ii;

                if isempty(inPort.Edges) || ~isvalid(inPort.Edges(1))
                    % Replace inN with 0 for disconnected inputs
                    expr = regexprep(expr, ...
                        '(?<![a-zA-Z_])' + varName + '(?![a-zA-Z_0-9])', '0');
                    continue
                end

                srcPort = inPort.Edges(1).SourcePort;
                inputExpr = resolvePortExpr(srcPort);

                if inputExpr ~= ""
                    hasAnyInput = true;
                    maxSpeed = max(maxSpeed, srcPort.Speed);
                    expr = regexprep(expr, ...
                        '(?<![a-zA-Z_])' + varName + '(?![a-zA-Z_0-9])', ...
                        "(" + inputExpr + ")");
                else
                    expr = regexprep(expr, ...
                        '(?<![a-zA-Z_])' + varName + '(?![a-zA-Z_0-9])', '0');
                end
            end

            if hasAnyInput && expr ~= ""
                outPort.Type       = "signal";
                outPort.Expression = expr;
                outPort.Speed      = maxSpeed;
            else
                outPort.Type = "static";
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

function expr = resolvePortExpr(srcPort)
    % Convert a source port to an expression string.
    switch srcPort.Type
        case "signal"
            expr = srcPort.Expression;
        case "flow"
            rate = srcPort.OutputRate;
            offset = srcPort.TimeOffset;
            if offset > 0
                expr = "pulse((t-" + string(offset) + ")*" ...
                    + string(rate) + ",0.05)";
            else
                expr = "pulse(t*" + string(rate) + ",0.05)";
            end
        otherwise
            expr = "";
    end
end
