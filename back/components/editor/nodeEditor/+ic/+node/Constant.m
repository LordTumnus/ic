classdef Constant < ic.node.Node
    % > CONSTANT Inline value node — compact pill with one output.
    %   Accepts numbers or strings. Numbers are auto-converted to string.
    %
    %   n = ic.node.Constant(Value="42")
    %   n = ic.node.Constant(Value=3.14)
    %   n = ic.node.Constant(Value="hello", BackgroundColor="#fef3c7")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE the value displayed in the pill (number or string)
        Value (1,1) string = "0"

        % > BACKGROUNDCOLOR pill fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR pill border color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Constant(props)
            % > CONSTANT Construct an inline value node.
            arguments
                props.?ic.node.Constant
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("value"), "outputs");
        end
    end
end
