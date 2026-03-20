classdef ClassNode < ic.node.Node
    % > CLASSNODE UML class diagram box with header and fields — one input and one output.
    %
    %   n = ic.node.ClassNode(Label="Person", Fields=["name: string", "age: int", "getName()"])
    %   n = ic.node.ClassNode(Label="Vehicle", Position=[300 100])

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL class name displayed in the header
        Label (1,1) string = "ClassName"

        % > FIELDS class fields and methods (e.g. ["name: string", "age: int", "getName()"])
        Fields (1,:) string = string.empty

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = ClassNode(props)
            % > CLASSNODE Construct a UML class diagram node.
            arguments
                props.?ic.node.ClassNode
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
