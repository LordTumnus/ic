classdef Input < ic.node.Node
    % > INPUT Pipeline entry terminal — double chevron >> with one output.
    %
    %   n = ic.node.Input(Label="Audio In")
    %   n = ic.node.Input(Position=[50 100], BackgroundColor="#3b82f6")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown below the node)
        Label (1,1) string = "Input"

        % > BACKGROUNDCOLOR chevron fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR chevron stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Input(props)
            % > INPUT Construct a pipeline entry terminal node.
            arguments
                props.?ic.node.Input
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
