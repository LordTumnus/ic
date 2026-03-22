classdef Process < ic.node.Node
    % > PROCESS Flowchart process step — rounded rectangle with one input and one output.
    %
    %   n = ic.node.Process(Label="Validate")
    %   n = ic.node.Process(Position=[200 100], BackgroundColor="#3b82f6")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown inside the node)
        Label (1,1) string = "Process"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Process(props)
            % > PROCESS Construct a flowchart process step node.
            arguments
                props.?ic.node.Process
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
