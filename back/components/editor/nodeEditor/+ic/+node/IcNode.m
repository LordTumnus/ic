classdef IcNode < ic.node.Node
    % > ICNODE Container node that hosts arbitrary IC components.
    %   Renders a resizable box with a header and a content area where
    %   standard IC components (buttons, sliders, labels, etc.) are placed.
    %
    %   node = ic.node.IcNode(Label="Controls", Width=250, Height=200)
    %   node.addContent(ic.Button(Label="Run"))
    %   node.addContent(ic.Slider(Value=0.5, Min=0, Max=1))

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL header text
        Label (1,1) string = "IcNode"

        % > WIDTH node width in pixels
        Width (1,1) double = 250

        % > HEIGHT node height in pixels
        Height (1,1) double = 200

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = IcNode(props)
            % > ICNODE Construct a container node.
            arguments
                props.?ic.node.IcNode
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
            % Add the "content" target for hosting IC components
            this.Targets = ["inputs", "outputs", "content"];
        end

        function addContent(this, child)
            % > ADDCONTENT Add an IC component to the node's content area.
            %
            %   node.addContent(ic.Button(Label="Click"))
            %   node.addContent(ic.Slider(Value=0.5))
            arguments
                this (1,1) ic.node.IcNode
                child (1,1) ic.core.Component
            end
            this.addChild(child, "content");
        end

        function validateChild(this, child, target)
            % > VALIDATECHILD Allow Ports in inputs/outputs, any Component in content.
            if target == "content"
                % Accept any IC component in the content target
                validateChild@ic.core.ComponentContainer(this, child, target);
            else
                % Delegate to Node's port-only validation for inputs/outputs
                validateChild@ic.node.Node(this, child, target);
            end
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("in"), "inputs");
            this.addPort(ic.node.Port("out"), "outputs");
        end
    end
end
