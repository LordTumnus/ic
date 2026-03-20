classdef Terminator < ic.node.Node
    % > TERMINATOR Flowchart start/end — stadium/pill shape with one input and one output.
    %
    %   n = ic.node.Terminator(Label="Start")
    %   n = ic.node.Terminator(Label="End", Position=[400 300])

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown inside the pill)
        Label (1,1) string = "Start"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Terminator(props)
            % > TERMINATOR Construct a flowchart start/end terminal node.
            arguments
                props.?ic.node.Terminator
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
