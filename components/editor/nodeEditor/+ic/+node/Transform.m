classdef Transform < ic.node.Node
    % > TRANSFORM f(x) math block — applies an expression to N channels.
    %   Each input port is paired with an output port. The Expression is
    %   applied independently to each channel. When an input signal arrives,
    %   the output expression wraps it: e.g. Expression="2*x" with input
    %   sin(t) produces output 2*(sin(t)).
    %
    %   t = ic.node.Transform(Expression="2*x", InputNumber=3)
    %   t = ic.node.Transform(Label="Scale", Expression="x + 1")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL header text
        Label (1,1) string = "Transform"

        % > EXPRESSION displayed expression applied to each input (e.g. "2*x")
        Expression (1,1) string = ""

        % > COLOR accent color (empty = theme default)
        Color (1,1) string = ""

        % > ICON header icon
        Icon ic.Asset = ic.Asset.empty

        % > INPUTNUMBER number of input/output port pairs
        InputNumber (1,1) double {mustBePositive, mustBeInteger} = 1
    end

    methods
        function this = Transform(props)
            % > TRANSFORM Construct a transform node.
            arguments
                props.?ic.node.Transform
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.InputNumber(this, val)
            oldVal = this.InputNumber;
            this.InputNumber = val;
            this.syncPorts(oldVal, val);
        end

        function set.Expression(this, val)
            this.Expression = val;
            this.syncAllOutputs();
        end

        function onPortEdgeChanged(this, port)
            % > ONPORTEDGECHANGED Called by Port when edges connect/disconnect.
            if startsWith(port.Name, "in")
                idx = extractAfter(port.Name, "in");
                this.syncOutput(str2double(idx));
            end
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            for ii = 1:this.InputNumber
                this.addPort(ic.node.Port("in" + ii, MaxConnections=1), "inputs");
                this.addPort(ic.node.Port("out" + ii), "outputs");
            end
            for ii = 1:this.InputNumber
                this.outputStatic("out" + ii);
            end
        end
    end

    methods (Access = private)
        function syncPorts(this, oldN, newN)
            % > SYNCPORTS Add or remove paired input/output ports.
            try
                if newN > oldN
                    for ii = (oldN+1):newN
                        this.addPort(ic.node.Port("in" + ii, MaxConnections=1), "inputs");
                        this.addPort(ic.node.Port("out" + ii), "outputs");
                    end
                elseif newN < oldN
                    for ii = oldN:-1:(newN+1)
                        inPort = this.findPort("in" + ii, "inputs");
                        outPort = this.findPort("out" + ii, "outputs");
                        this.removePort(inPort);
                        this.removePort(outPort);
                    end
                end
            catch
                return
            end
            this.syncAllOutputs();
        end

        function syncAllOutputs(this)
            % > SYNCALLOUTPUTS Recompute all output port expressions.
            for ii = 1:this.InputNumber
                this.syncOutput(ii);
            end
        end

        function syncOutput(this, idx)
            % > SYNCOUTPUT Compute output expression for port pair idx.
            try
                outPort = this.findPort("out" + idx, "outputs");
                inPort  = this.findPort("in" + idx, "inputs");
            catch
                return
            end

            oldType = outPort.Type;

            if isempty(inPort.Edges) || ~isvalid(inPort.Edges(1))
                outPort.Type = "static";
            else
                srcPort = inPort.Edges(1).SourcePort;
                expr = resolvePortExpr(srcPort);
                if expr ~= ""
                    outPort.Type       = "signal";
                    outPort.Expression = applyTransform(this.Expression, expr);
                    outPort.Speed      = srcPort.Speed;
                else
                    outPort.Type = "static";
                end
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

function out = applyTransform(transformExpr, inputExpr)
    % Replace 'x' in the transform expression with the input expression.
    if transformExpr == ""
        out = inputExpr;
    else
        out = regexprep(transformExpr, ...
            '(?<![a-zA-Z_])x(?![a-zA-Z_0-9])', ...
            "(" + inputExpr + ")");
    end
end
