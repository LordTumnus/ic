classdef Output < ic.node.Node
    % > OUTPUT Pipeline exit terminal — double chevron << with one input.
    %
    %   n = ic.node.Output(Label="Audio Out")
    %   n = ic.node.Output(Position=[800 100], BackgroundColor="#8b5cf6")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown below the node)
        Label (1,1) string = "Output"

        % > BACKGROUNDCOLOR chevron fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR chevron stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Output(props)
            % > OUTPUT Construct a pipeline exit terminal node.
            arguments
                props.?ic.node.Output
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("value"), "inputs");
        end
    end
end
