classdef Database < ic.node.Node
    % > DATABASE Cylinder shape for data stores — one input and one output.
    %
    %   n = ic.node.Database(Label="Users")
    %   n = ic.node.Database(Position=[100 200], BackgroundColor="#6366f1")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown inside the cylinder)
        Label (1,1) string = "Database"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Database(props)
            % > DATABASE Construct a data store node.
            arguments
                props.?ic.node.Database
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
