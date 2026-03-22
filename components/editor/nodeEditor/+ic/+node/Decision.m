classdef Decision < ic.node.Node
    % > DECISION Flowchart diamond — yes/no branching with one input and two outputs.
    %
    %   n = ic.node.Decision(Label="x > 0?")
    %   n = ic.node.Decision(Position=[300 200], BackgroundColor="#f59e0b")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown inside the diamond)
        Label (1,1) string = "?"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Decision(props)
            % > DECISION Construct a flowchart decision node.
            arguments
                props.?ic.node.Decision
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("in"), "inputs");
            this.addPort(ic.node.Port("yes"), "outputs");
            this.addPort(ic.node.Port("no"), "outputs");
        end
    end
end
