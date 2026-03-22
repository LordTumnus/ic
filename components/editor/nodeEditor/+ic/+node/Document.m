classdef Document < ic.node.Node
    % > DOCUMENT Page shape with wavy bottom edge — one input and one output.
    %
    %   n = ic.node.Document(Label="Report")
    %   n = ic.node.Document(Position=[350 100], BackgroundColor="#f97316")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown inside the document)
        Label (1,1) string = "Document"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Document(props)
            % > DOCUMENT Construct a document node.
            arguments
                props.?ic.node.Document
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
