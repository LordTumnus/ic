classdef Queue < ic.node.Node
    % > QUEUE Horizontal cylinder for queues/buffers — one input and one output.
    %
    %   n = ic.node.Queue(Label="Message Queue")
    %   n = ic.node.Queue(Position=[150 250], BackgroundColor="#8b5cf6")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown inside the cylinder)
        Label (1,1) string = "Queue"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Queue(props)
            % > QUEUE Construct a queue/buffer node.
            arguments
                props.?ic.node.Queue
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
