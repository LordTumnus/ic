classdef Actor < ic.node.Node
    % > ACTOR UML stick figure actor — one input and one output.
    %
    %   n = ic.node.Actor(Label="User")
    %   n = ic.node.Actor(Position=[50 50], BackgroundColor="#10b981")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown below the stick figure)
        Label (1,1) string = "Actor"

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Actor(props)
            % > ACTOR Construct a UML actor node.
            arguments
                props.?ic.node.Actor
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
