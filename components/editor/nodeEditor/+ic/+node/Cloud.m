classdef Cloud < ic.node.Node
    % > CLOUD Cloud shape for external services/APIs — one input and one output.
    %
    %   n = ic.node.Cloud(Label="REST API")
    %   n = ic.node.Cloud(Position=[250 150], BackgroundColor="#06b6d4")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown inside the cloud)
        Label (1,1) string = "Service"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Cloud(props)
            % > CLOUD Construct an external service node.
            arguments
                props.?ic.node.Cloud
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("in"), "inputs");
            this.addPort(ic.node.Port("out"), "outputs");
        end
    end
end
