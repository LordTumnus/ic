classdef Transform < ic.node.Node
    % > TRANSFORM f(x) math block — displays an expression.
    %   Test node for Session 1. Has 1 input + 1 output.
    %
    %   t = ic.node.Transform(Label="Scale", Expression="x * 2")
    %   t = ic.node.Transform(Position=[300 200])

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL header text
        Label (1,1) string = "Transform"

        % > EXPRESSION displayed expression (e.g. "x + 1")
        Expression (1,1) string = ""

        % > COLOR accent color (empty = theme default)
        Color (1,1) string = ""

        % > ICON header icon
        Icon ic.asset.Asset = ic.asset.Asset.empty
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
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("data", Label="In"), "inputs");
            this.addPort(ic.node.Port("data", Label="Out"), "outputs");
        end
    end
end
